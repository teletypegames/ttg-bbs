# frozen_string_literal: true

require_relative 'windows/board'
require_relative 'windows/messages'
require_relative 'windows/mail'
require_relative 'windows/chat'
require_relative 'windows/people'
require_relative 'windows/you'
require_relative 'windows/doors'

module UI
  module Modern
    # The windows of the desktop: each a module that configures its
    # BBS::WindowSpec, listed here with its name and kind.
    module Windows
      ALL = {
        system_info:     [:info,          SystemInfo],
        bulletins:       [:master_detail, Bulletins],
        dev_log:         [:master_detail, DevLog],
        messages:        [:master_detail, Messages],
        compose_message: [:form,          ComposeMessage],
        oneliners:       [:info,          Oneliners],
        voting:          [:master_detail, Voting],
        mail:            [:master_detail, Mail],
        compose_mail:    [:form,          ComposeMail],
        chat:            [:stream,        Chat],
        irc:             [:stream,        Irc],
        master:          [:stream,        Master],
        team:            [:info,          Team],
        online_users:    [:info,          OnlineUsers],
        last_callers:    [:info,          LastCallers],
        user_list:       [:info,          UserList],
        hall_of_fame:    [:info,          HallOfFame],
        register:        [:form,          Register],
        profile:         [:form,          Profile],
        my_stats:        [:info,          MyStats],
        sysop_console:   [:info,          SysopConsole],
        doors:           [:master_detail, Doors]
      }.freeze

      # Registers every window on the Application.define +builder+.
      def self.define(builder)
        ALL.each { |name, (type, spec)| builder.window(name, type: type) { |w| spec.configure(w) } }
      end

      # A form's answer to a refused submit: the error under the fields.
      def self.refuse(form, text)
        form.error(text)
        :keep
      end
    end
  end
end
