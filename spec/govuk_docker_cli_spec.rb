require "spec_helper"
require_relative "../lib/govuk_docker_cli"

describe GovukDockerCLI do
  let(:command) { nil }
  let(:args) { [] }
  subject { described_class.start([command] + args) }
  let(:command_double) { double }
  before { allow(command_double).to receive(:call) }

  describe "run" do
    let(:command) { "run" }

    context "without a stack argument" do
      it "runs in the default stack" do
        expect(Commands::Run)
          .to receive(:new).with("default", [])
          .and_return(command_double)
        subject
      end
    end

    context "with a stack argument" do
      let(:args) { ["--stack", "backend"] }

      it "runs in the specified stack" do
        expect(Commands::Run)
          .to receive(:new).with("backend", [])
          .and_return(command_double)
        subject
      end
    end

    context "with additional arguments" do
      let(:args) { ["bundle", "exec", "rspec"] }

      it "runs the command with additinal arguments" do
        expect(Commands::Run)
          .to receive(:new).with("default", ["bundle", "exec", "rspec"])
          .and_return(command_double)
        subject
      end
    end
  end
end
