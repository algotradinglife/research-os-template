#!/usr/bin/env ruby

require "pathname"
require "yaml"

class ScenarioError < StandardError; end

def load_yaml(path)
  raise ScenarioError, "missing file: #{path}" unless path.exist?

  YAML.safe_load(
    path.read,
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false
  )
end

def write_yaml(path, content)
  path.dirname.mkpath
  path.write(YAML.dump(content))
end

def set_graph_state(graph, node_id, state)
  node = graph.dig("spec", "nodes").find { |candidate| candidate["id"] == node_id }
  raise ScenarioError, "graph is missing node #{node_id}" unless node

  node["state"] = state
end

scenario = Pathname.new(ARGV.fetch(0) { raise ScenarioError, "usage: ruby scripts/e2e.rb SCENARIO" }).expand_path
research_root = scenario.join(".research")
project = load_yaml(research_root.join("project.yaml"))
graph_path = research_root.join("graph.yaml")
graph = load_yaml(graph_path)
task_paths = research_root.glob("tasks/*.yaml")

raise ScenarioError, "scenario must contain exactly one task" unless task_paths.length == 1

task_path = task_paths.fetch(0)
task = load_yaml(task_path)
executor_result = load_yaml(scenario.join("fixtures/executor-result.yaml"))
validation_result = load_yaml(scenario.join("fixtures/validation-result.yaml"))
human_decision_path = scenario.join("fixtures/human-decision.yaml")
human_decision = load_yaml(human_decision_path) if human_decision_path.exist?

project_id = project.dig("metadata", "id")
raise ScenarioError, "graph project does not match project" unless graph.dig("metadata", "project_id") == project_id
raise ScenarioError, "task project does not match project" unless task.dig("metadata", "project_id") == project_id
raise ScenarioError, "task must start in CREATED" unless task.dig("status", "current") == "CREATED"
raise ScenarioError, "executor did not complete" unless executor_result["status"] == "completed"
raise ScenarioError, "validation did not pass" unless validation_result["status"] == "passed"
raise ScenarioError, "medium-risk scenario requires independent validation" unless validation_result["independent"]

required_artifacts = task.dig("spec", "acceptance", "required_artifacts") || []
artifact_refs = executor_result["artifact_refs"] || []
artifact_types = artifact_refs.map { |artifact| artifact["artifact_type"] }
missing_artifacts = required_artifacts - artifact_types
raise ScenarioError, "missing required artifacts: #{missing_artifacts.join(", ")}" unless missing_artifacts.empty?

artifact_refs.each do |artifact|
  artifact_path = scenario.join(artifact.fetch("uri"))
  raise ScenarioError, "artifact does not exist: #{artifact["uri"]}" unless artifact_path.exist?
end

task["status"]["routing"] =
  if task.dig("spec", "type") == "research" && task.dig("spec", "execution", "uncertainty") == "high"
    {
      "executor_mode" => "isolated_session",
      "profile" => "researcher",
      "runtime" => "stub",
      "reason" => "research task with high uncertainty"
    }
  else
    raise ScenarioError, "minimal runner supports only high-uncertainty research routing"
  end

task["status"]["current"] = "AWAITING_DECISION"
task["status"]["artifacts"] = artifact_refs
task["status"]["result"] = {
  "findings" => executor_result["findings"],
  "limitations" => executor_result["limitations"]
}

transitions = [
  ["CREATED", "PLANNING", "hermes-controller", "intent and project policy loaded"],
  ["PLANNING", "READY", "hermes-controller", "acceptance and routing inputs present"],
  ["READY", "EXECUTING", "hermes-controller", "stub executor bound"],
  ["EXECUTING", "VALIDATING", "stub-executor", "required artifacts registered"],
  ["VALIDATING", "AWAITING_DECISION", validation_result["reviewer"], "independent validation passed"]
]

def audit_events(transitions)
  transitions.map.with_index do |(from, to, actor, reason), index|
    {
      "sequence" => index + 1,
      "from" => from,
      "to" => to,
      "actor" => actor,
      "reason" => reason
    }
  end
end

events = audit_events(transitions)
task["status"]["history"] = events
audit = {
  "api_version" => "research-os/v0.1",
  "kind" => "AuditLog",
  "metadata" => {
    "task_id" => task.dig("metadata", "id"),
    "project_id" => project_id
  },
  "events" => events
}

set_graph_state(graph, task.dig("metadata", "id"), "AWAITING_DECISION")
set_graph_state(graph, "E2E-EVIDENCE-001", "GENERATED")
set_graph_state(graph, "E2E-DECISION-001", "AWAITING_DECISION")

unless human_decision
  write_yaml(task_path, task)
  write_yaml(graph_path, graph)
  write_yaml(research_root.join("audit/#{task.dig("metadata", "id")}.yaml"), audit)
  warn "human decision required"
  exit 2
end

allowed_outcomes = %w[supported partially_supported refuted inconclusive more_evidence_required]
unless allowed_outcomes.include?(human_decision["outcome"])
  raise ScenarioError, "invalid human decision outcome"
end

transitions << [
  "AWAITING_DECISION",
  "COMPLETED",
  human_decision["owner"],
  "human decision recorded"
]
events = audit_events(transitions)
task["status"]["current"] = "COMPLETED"
task["status"]["result"]["decision"] = human_decision
task["status"]["history"] = events
audit["events"] = events
set_graph_state(graph, task.dig("metadata", "id"), "COMPLETED")
set_graph_state(graph, "E2E-DECISION-001", "RECORDED")

memory = {
  "api_version" => "research-os/v0.1",
  "kind" => "MemoryRecord",
  "metadata" => {
    "id" => "E2E-MEM-001",
    "project_id" => project_id,
    "version" => "0.1.0",
    "created_at" => human_decision.fetch("decided_at").split("T").first
  },
  "spec" => {
    "type" => "decision",
    "maturity" => "reviewed",
    "statement" => "Research outcome #{human_decision["outcome"]}: #{human_decision["reason"]}",
    "outcome" => human_decision["outcome"],
    "provenance" => {
      "task_ids" => [task.dig("metadata", "id")],
      "artifact_refs" => artifact_refs
    },
    "confidence" => "low",
    "scope" => {
      "scenario" => "minimal-controller-e2e"
    },
    "limitations" => executor_result["limitations"],
    "supersedes" => [],
    "review_due" => nil
  }
}

write_yaml(task_path, task)
write_yaml(graph_path, graph)
write_yaml(research_root.join("audit/#{task.dig("metadata", "id")}.yaml"), audit)
write_yaml(research_root.join("memory/E2E-MEM-001.yaml"), memory)
puts "completed #{task.dig("metadata", "id")}"
