module Exhaust
  class Runner

    attr_reader :configuration
    def initialize(configuration=Exhaust::Configuration.new)
      @configuration = configuration
    end

    def run
      Timeout::timeout(70) do
        while running = ember_server.gets
          puts running
          if running =~ /build successful/i
            # Just to be safe
            sleep 1
            break
          end
        end

        while running = rails_server.gets
          puts running
          if running =~ /listening/i
            break
          end
        end
      end
    end

    def ember_host
      "http://localhost:#{ember_port}"
    end

    def ember_port
      configuration.ember_port.to_s
    end

    def ember_log
      configuration.ember_log
    end

    def rails_port
      configuration.rails_port.to_s
    end

    def rails_log
      configuration.rails_log
    end

    def ember_path
      configuration.ember_path
    end

    def rails_path
      configuration.rails_path
    end

    def popen_and_setpgid(cmd)
      read, write = IO.pipe
      pid = Process.fork do
        Process.setpgid(Process.pid, Process.pid)
        Process.exec(cmd, out: write)
      end
      [ read, pid ]
    end

    def ember_server
      @ember_server ||= begin
        Dir.chdir(ember_path) do
          ember_cmd = "API_HOST=http://localhost:#{rails_port} ember server --port #{ember_port} --live-reload false"
          @ember_server, @ember_pid = popen_and_setpgid("#{ember_cmd} | tee #{ember_log}")
          @ember_server
        end
      end
    end

    def rails_server
      @rails_server ||= begin
        Dir.chdir(rails_path) do
          rails_cmd = "rails server --port #{rails_port} --environment test"
          @rails_server, @rails_pid = popen_and_setpgid(rails_cmd)
          @rails_server
        end
      end
    end

    def shutdown!
      Process.kill(15, -Process.getpgid(@ember_pid), -Process.getpgid(@rails_pid))
      @rails_server = nil
      @ember_server = nil
      @rails_pid = nil
      @ember_pid = nil
    end
  end
end
