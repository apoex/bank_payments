module BankPayments
  module SwedbankImport
    class AccountRecord < SpisuRecord

      define_field :debit_account,     '2:12:N'
      define_field :transaction_date, '13:18:N'

      def initialize(raw_record)
        super
        self.type = '1'
      end
    end
  end
end
