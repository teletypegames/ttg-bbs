# frozen_string_literal: true

require 'erb'

module BBS
  class Renderer
    TEMPLATE_DIR = File.expand_path('templates', __dir__)

    def self.render(name, vars = {})
      path = File.join(TEMPLATE_DIR, "#{name}.erb")
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
