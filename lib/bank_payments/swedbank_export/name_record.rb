module BankPayments
  module SwedbankExport
    class NameRecord < SpisuRecord

      define_field :serial_number, '2:8:N'
      define_field :name,          '9:73:AN'

      def initialize
        super
        self.type = '2'
      end

    end
  end
end