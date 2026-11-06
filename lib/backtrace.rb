# frozen_string_literal: true

# Captures the trace behind a crash, for ErrorDialog to show.
#
# Ported from upstream's src/exm-backtrace.c, but the library it wraps —
# `libbacktrace`, walking native stack frames by address against the
# compiled binary's debug symbols — has nothing to port: this app is
# interpreted Ruby, not a compiled binary, and every frame on the way to a
# crash is already a Ruby `Exception#backtrace` entry carrying its own file,
# line and method name. `Backtrace.install` is upstream's
# `exm_backtrace_init` for that difference: instead of arming a signal
# handler around a native crash, it wraps the block that runs the
# application (and, within it, every signal callback the main loop invokes)
# in a rescue, so an exception that would otherwise print to stderr and kill
# the process is handed to the block as upstream's exm_backtrace_print hands
# a formatted string to the crash reporter.
module Backtrace
  # Upstream's "N frames omitted" line, collapsed here into one message
  # rather than counted per contiguous run: Ruby's backtrace has no
  # unresolvable native frames to begin with, so there is nothing to count.
  NO_BACKTRACE = '(no backtrace available)'

  # Upstream's exm_backtrace_print: formats one exception as upstream
  # formats one frame, `filename:lineno 'function'`, one per line, oldest
  # call first — which is the order Ruby's own #backtrace already returns
  # it in.
  def self.format(error)
    "#{error.class}: #{error.message}\n#{frames(error).join("\n")}"
  end

  def self.frames(error)
    Array(error.backtrace).map { |line| line.sub(/\A(.+):(\d+):in\s+(.*)\z/, "\\1:\\2 '\\3'") }.then do |lines|
      if lines.empty?
        [NO_BACKTRACE]
      else
        lines
      end
    end
  end

  # Upstream's exm_backtrace_init, called once at startup. Runs `block`
  # (ordinarily the application's own `#run`) and, if an exception escapes
  # it uncaught, formats it and hands the text to `on_crash` instead of
  # letting the process die with a bare stack trace on stderr — the same
  # moment upstream's installed signal handler would fire for a native
  # crash.
  def self.install(on_crash, &block)
    block.call
  rescue Exception => e # rubocop:disable Lint/RescueException
    on_crash.call(format(e))
    if e.is_a?(SystemExit) || e.is_a?(SignalException)
      raise
    end
  end
end
