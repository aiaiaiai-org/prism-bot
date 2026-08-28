# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class LifecycleGateTest < Minitest::Test
  include PrismBotTestSupport

  def test_blocks_ordinary_command_when_personal_instance_is_paused
    lifecycle = FakeBotLifecycle.new(status: "paused")
    gate = build_gate(lifecycle)

    state = gate.call(telegram_update(text: "/publish hello"))

    assert state.paused?
    assert_equal :status, lifecycle.requests.fetch(0).fetch(:operation)
    assert_equal "7", lifecycle.requests.fetch(0).fetch(:subject_id)
  end

  def test_allows_ordinary_command_when_personal_instance_is_active
    lifecycle = FakeBotLifecycle.new(status: "active")

    assert_nil build_gate(lifecycle).call(telegram_update(text: "/channels"))
    assert_equal 1, lifecycle.requests.length
  end

  def test_lifecycle_and_safe_commands_bypass_status_gate
    lifecycle = FakeBotLifecycle.new(status: "paused")
    gate = build_gate(lifecycle)

    %w[/start /help /status /stop /resume].each do |text|
      assert_nil gate.call(telegram_update(text: text))
    end

    assert_empty lifecycle.requests
  end

  private

  def build_gate(lifecycle)
    controller = PrismBot::Channels::Telegram::LifecycleController.new(
      bot_lifecycle: PrismBot::UseCases::ManageBotLifecycle.new(bot_lifecycle: lifecycle)
    )
    PrismBot::Channels::Telegram::LifecycleGate.new(lifecycle: controller)
  end
end
