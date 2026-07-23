#!/usr/bin/env ruby

require "yaml"
require "pathname"

ROOT = Pathname.new(__dir__).parent
CONFIG_GLOBS = [
  "kernel/**/*.yaml",
  "template/**/*.yaml",
  "examples/**/*.yaml"
].freeze

errors = []
documents = {}

CONFIG_GLOBS.each do |glob|
  ROOT.glob(glob).sort.each do |path|
    begin
      documents[path.relative_path_from(ROOT).to_s] =
        YAML.safe_load(path.read, permitted_classes: [], permitted_symbols: [], aliases: false)
    rescue StandardError => e
      errors << "#{path.relative_path_from(ROOT)}: YAML parse error: #{e.message}"
    end
  end
end

def require_keys(errors, file, object, keys, context)
  unless object.is_a?(Hash)
    errors << "#{file}: #{context} must be a mapping"
    return
  end

  keys.each do |key|
    errors << "#{file}: missing #{context}.#{key}" unless object.key?(key)
  end
end

state_doc = documents["kernel/workflows/state-machine.yaml"]
profile_doc = documents["kernel/profiles/agent-profiles.yaml"]
routing_doc = documents["kernel/policies/routing-policy.yaml"]

states = state_doc&.fetch("states", {})&.keys || []
executor_modes = profile_doc&.fetch("executor_modes", []) || []
profile_names = profile_doc&.fetch("profiles", {})&.keys || []

if state_doc
  state_doc.fetch("transitions", []).each do |transition|
    origins = Array(transition["from"]) + Array(transition["from_any"])
    origins.each do |origin|
      errors << "state-machine: unknown origin state #{origin}" unless states.include?(origin)
    end
    target = transition["to"]
    errors << "state-machine: unknown target state #{target}" unless states.include?(target)
  end
end

if routing_doc
  routing_doc.fetch("rules", []).each do |rule|
    action = rule.fetch("action", {})
    mode = action["executor_mode"]
    profile = action["profile"]
    if mode && !executor_modes.include?(mode)
      errors << "routing-policy: rule #{rule["id"]} references unknown executor mode #{mode}"
    end
    if profile && !profile_names.include?(profile) && profile != "research_owner"
      errors << "routing-policy: rule #{rule["id"]} references unknown profile #{profile}"
    end
  end
end

documents.each do |file, doc|
  next unless doc.is_a?(Hash) && doc["kind"]

  require_keys(errors, file, doc, %w[api_version kind], "document")

  case doc["kind"]
  when "Project"
    require_keys(errors, file, doc, %w[metadata spec], "project")
    require_keys(errors, file, doc["metadata"], %w[id name version], "metadata")
    require_keys(errors, file, doc["spec"], %w[domain objectives evaluation policies], "spec")
  when "Task"
    require_keys(errors, file, doc, %w[metadata spec status], "task")
    require_keys(errors, file, doc["metadata"], %w[id title project_id version], "metadata")
    require_keys(errors, file, doc["spec"], %w[type intent execution risk acceptance], "spec")
    require_keys(errors, file, doc["status"], %w[current attempts routing artifacts], "status")

    type = doc.dig("spec", "type")
    errors << "#{file}: invalid task type #{type}" unless %w[research capability maintenance].include?(type)

    current = doc.dig("status", "current")
    errors << "#{file}: unknown current state #{current}" unless states.include?(current)

    mode = doc.dig("status", "routing", "executor_mode")
    if mode && !executor_modes.include?(mode)
      errors << "#{file}: unknown executor mode #{mode}"
    end

    profile = doc.dig("status", "routing", "profile")
    if profile && !profile_names.include?(profile)
      errors << "#{file}: unknown profile #{profile}"
    end
  when "Graph"
    require_keys(errors, file, doc, %w[metadata spec], "graph")
    nodes = doc.dig("spec", "nodes") || []
    edges = doc.dig("spec", "edges") || []
    ids = nodes.map { |node| node["id"] }

    duplicates = ids.group_by(&:itself).select { |_id, entries| entries.length > 1 }.keys
    duplicates.each { |id| errors << "#{file}: duplicate graph node #{id}" }

    edges.each do |edge|
      %w[from to relation].each do |key|
        errors << "#{file}: graph edge missing #{key}" unless edge.key?(key)
      end
      errors << "#{file}: edge source #{edge["from"]} is missing" unless ids.include?(edge["from"])
      errors << "#{file}: edge target #{edge["to"]} is missing" unless ids.include?(edge["to"])
      errors << "#{file}: self-loop at #{edge["from"]}" if edge["from"] == edge["to"]
    end

    graph_dir = ROOT.join(file).dirname
    nodes.each do |node|
      ref = node["ref"]
      next unless ref.is_a?(String)

      local_ref = ref.split("#", 2).first
      next if local_ref.empty? || local_ref.match?(%r{\A[a-z]+://})

      errors << "#{file}: node #{node["id"]} references missing file #{local_ref}" unless graph_dir.join(local_ref).exist?
    end

    adjacency = Hash.new { |hash, key| hash[key] = [] }
    edges.each { |edge| adjacency[edge["from"]] << edge["to"] }
    visiting = {}
    visited = {}
    cycle_found = false

    visit = lambda do |node_id|
      return if visited[node_id] || cycle_found
      if visiting[node_id]
        cycle_found = true
        return
      end

      visiting[node_id] = true
      adjacency[node_id].each { |target| visit.call(target) }
      visiting.delete(node_id)
      visited[node_id] = true
    end

    ids.each { |id| visit.call(id) }
    errors << "#{file}: graph contains a cycle" if cycle_found
  when "MemoryRecord"
    require_keys(errors, file, doc, %w[metadata spec], "memory")
    require_keys(errors, file, doc["metadata"], %w[id project_id version created_at], "metadata")
    require_keys(
      errors,
      file,
      doc["spec"],
      %w[type maturity statement provenance confidence limitations],
      "spec"
    )
    maturity = doc.dig("spec", "maturity")
    allowed = %w[raw preliminary reviewed validated adopted deprecated]
    errors << "#{file}: invalid memory maturity #{maturity}" unless allowed.include?(maturity)
  end
end

if errors.empty?
  puts "Validated #{documents.length} YAML documents."
  exit 0
end

warn "Validation failed:"
errors.each { |error| warn "- #{error}" }
exit 1
