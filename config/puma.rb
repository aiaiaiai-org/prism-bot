# © 2026 aiaiaiai · aiaiaiai.org

threads_count = ENV.fetch("PUMA_MAX_THREADS", 5)
threads threads_count, threads_count

port ENV.fetch("PORT", 3001)
environment ENV.fetch("RACK_ENV", "development")

plugin :tmp_restart
