require "fileutils"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"
require "yaml"

class MinimalControllerE2ETest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  SCENARIO = ROOT.join("tests/e2e/minimal-research")
  RUNNER = ROOT.join("scripts/e2e.rb")

  def run_scenario
    Dir.mktmpdir("research-os-e2e") do |directory|
      workspace = Pathname.new(directory).join("minimal-research")
      FileUtils.cp_r(SCENARIO, workspace)

      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        RUNNER.to_s,
        workspace.to_s,
        chdir: ROOT.to_s
      )

      assert status.success?, "runner failed:\nstdout: #{stdout}\nstderr: #{stderr}"
      yield workspace, stdout
    end
  end

  def test_research_task_reaches_completed_state
    run_scenario do |workspace, _stdout|
      task = YAML.safe_load(
        workspace.join(".research/tasks/E2E-001.yaml").read,
        permitted_classes: [],
        aliases: false
      )

      assert_equal "COMPLETED", task.dig("status", "current")
    end
  end

  def test_high_uncertainty_research_is_routed_to_isolated_researcher
    run_scenario do |workspace, _stdout|
      task = YAML.safe_load(
        workspace.join(".research/tasks/E2E-001.yaml").read,
        permitted_classes: [],
        aliases: false
      )

      assert_equal(
        {
          "executor_mode" => "isolated_session",
          "profile" => "researcher",
          "runtime" => "stub",
          "reason" => "research task with high uncertainty"
        },
        task.dig("status", "routing")
      )
    end
  end

  def test_audit_records_each_state_transition
    run_scenario do |workspace, _stdout|
      audit = YAML.safe_load(
        workspace.join(".research/audit/E2E-001.yaml").read,
        permitted_classes: [],
        aliases: false
      )

      transitions = audit.fetch("events").map { |event| "#{event["from"]}->#{event["to"]}" }
      assert_equal(
        [
          "CREATED->PLANNING",
          "PLANNING->READY",
          "READY->EXECUTING",
          "EXECUTING->VALIDATING",
          "VALIDATING->AWAITING_DECISION",
          "AWAITING_DECISION->COMPLETED"
        ],
        transitions
      )
    end
  end

  def test_inconclusive_decision_creates_reviewed_memory_candidate
    run_scenario do |workspace, _stdout|
      memory = YAML.safe_load(
        workspace.join(".research/memory/E2E-MEM-001.yaml").read,
        permitted_classes: [],
        aliases: false
      )

      observed = {
        "type" => memory.dig("spec", "type"),
        "maturity" => memory.dig("spec", "maturity"),
        "outcome" => memory.dig("spec", "outcome"),
        "task_ids" => memory.dig("spec", "provenance", "task_ids"),
        "artifact_types" => memory.dig("spec", "provenance", "artifact_refs").map { |ref| ref["artifact_type"] },
        "limitations" => memory.dig("spec", "limitations")
      }

      assert_equal(
        {
          "type" => "decision",
          "maturity" => "reviewed",
          "outcome" => "inconclusive",
          "task_ids" => ["E2E-001"],
          "artifact_types" => ["research_plan", "evidence_report", "input_manifest"],
          "limitations" => ["The result is deterministic and has no domain evidence."]
        },
        observed
      )
    end
  end

  def test_research_task_stops_at_human_gate_without_decision
    Dir.mktmpdir("research-os-e2e-gate") do |directory|
      workspace = Pathname.new(directory).join("minimal-research")
      FileUtils.cp_r(SCENARIO, workspace)
      workspace.join("fixtures/human-decision.yaml").delete

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        RUNNER.to_s,
        workspace.to_s,
        chdir: ROOT.to_s
      )
      task = YAML.safe_load(
        workspace.join(".research/tasks/E2E-001.yaml").read,
        permitted_classes: [],
        aliases: false
      )

      assert_equal(
        {
          "exit_status" => 2,
          "state" => "AWAITING_DECISION",
          "message" => "human decision required\n"
        },
        {
          "exit_status" => status.exitstatus,
          "state" => task.dig("status", "current"),
          "message" => stderr
        }
      )
    end
  end

  def test_completed_task_updates_graph_nodes
    run_scenario do |workspace, _stdout|
      graph = YAML.safe_load(
        workspace.join(".research/graph.yaml").read,
        permitted_classes: [],
        aliases: false
      )
      states = graph.dig("spec", "nodes").to_h { |node| [node["id"], node["state"]] }

      assert_equal(
        {
          "E2E-GOAL-001" => "ACTIVE",
          "E2E-001" => "COMPLETED",
          "E2E-EVIDENCE-001" => "GENERATED",
          "E2E-DECISION-001" => "RECORDED"
        },
        states
      )
    end
  end
end
