# frozen_string_literal: true

# The board itself, whatever terminal a caller has: its settings (SILICONIA_BBS_*) and its
# services. Both faces (lib/ui/modern, lib/ui/petscii) get the services by name.
class SiliconiaBBS
  include Rubbs::Common::Board::Domain

  path :notices_file, 'config/notices.yml', env: 'NOTICES'

  service(:notices) { NoticeService.new(NoticeRepository.new(notices_file)) }
end
