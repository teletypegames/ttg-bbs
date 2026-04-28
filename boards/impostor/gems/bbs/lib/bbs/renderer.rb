# frozen_string_literal: true

require 'erb'

module BBS
  class Renderer
    def self.render(name, vars = {})
      dir  = BBS.config.screens_dir or raise "BBS.config.screens_dir is not set"
      path = File.join(dir, "#{name}.erb")
      ctx  = Context.new(vars)
      ERB.new(File.read(path), trim_mode: '-').result(ctx.ctx_binding).gsub("\n", "\r\n")
    end

    class Context
      def initialize(vars)
        vars.each { |k, v| instance_variable_set(:"@#{k}", v) }
      end

      def ctx_binding = binding

      def clr       = "\e[2J\e[H"
      def reset     = "\e[0m"
      def green     = "\e[1;32m"
      def yellow    = "\e[1;33m"
      def cyan      = "\e[1;36m"
      def white     = "\e[1;37m"
      def gray      = "\e[0;37m"
      def red       = "\e[1;31m"
      def dim_green = "\e[0;32m"
    end
  end
end
