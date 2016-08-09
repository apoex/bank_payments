require 'spec_helper'

describe 'BankPayments::SwedbankExport - Records' do

  context "with an abstract record" do
    subject { BankPayments::SwedbankExport::Record }

    it "has correct length" do
      expect(subject.new.to_s.size).to eq 80
    end

    it "sets a record id" do
      record = subject.new
      record.type = 1
      expect(record.type).to eq '1'
    end

    it "can pad with zeroes" do
      record = subject.new
      record.set_numeric_value(10,20,120)
      expect(record.to_s).to eq \
        "         00000000120                                                            "
    end

    it "can pad with blanks" do
      record = subject.new
      record.set_numeric_value(1,80,'')
      record.set_text_value(3,10,'data')
      expect(record.to_s).to eq \
        "00DATA    0000000000000000000000000000000000000000000000000000000000000000000000"
    end

    it "only overload the correct methods" do
      record = subject.new
      expect {
        record.some_random_method
      }.to raise_error(NoMethodError)
    end
  end

  context "with an opening record" do
    subject { BankPayments::SwedbankExport::OpeningRecord }

    it "sets type to zero" do
      record = subject.new
      expect(record.type).to eq '0'
    end

    it "sets bankgiro correctly" do
      record = subject.new
      record.account = '6381040'
      expect(record.to_s).to match /6381040/
      expect(record.account).to eq '6381040'
    end

    it "sets the file date with the right format"  do
      record = subject.new
      record.creation_date = Date.new(2016,8,5)
      expect(record.to_s).to match /160805/
      expect(record.creation_date).to eq '160805'
      expect(record.creation_date.size).to eq 6
    end

    it "can contain an optional long name" do
      record = subject.new
      record.name = 'Globally Fantastic Machinery Inc.'
      expect(record.name).to eq 'GLOBALLY FANTASTIC MAC'
      expect(record.name.size).to eq 22
      expect(record.to_s).to match /GLOBALLY FANTASTIC/
      expect(record.to_s[15,22]).to eq 'GLOBALLY FANTASTIC MAC'
    end

    it "can contain an optional send address" do
      record = subject.new
      record.address = 'Virkesvägen 12'
      expect(record.address).to eq 'VIRKESVÄGEN 12'
    end

    # This requires that all payment records (type = 6) are zeroed out.
    # TODO Create a nice implementation of this rule with associated
    # validations
    it "can set an explicit payment date" do
      record = subject.new
      record.pay_date = Date.new(2016,8,5)
      expect(record.to_s).to match /160805/
      expect(record.to_s[72,6]).to eq '160805'
      expect(record.pay_date).to eq '160805'
      expect(record.pay_date.size).to eq 6
    end
  end

  context "with a name record" do
    subject { BankPayments::SwedbankExport::NameRecord }

    it "creates a correct name record" do
      record = subject.new
      record.serial_number = 1 # This sould be generated by the payment
      record.name          = "Abo OY"

      expect(record.to_s).to eq \
        '20000001ABO OY                                                                  '
    end
  end

  context "with an address record" do
    subject { BankPayments::SwedbankExport::AddressRecord }

    it "sets the right values in the right places" do
      address = subject.new
      address.serial_number = 1
      address.address       = 'Virkesvägen 12 120 30 Stockholm'
      address.country_code  = 'SE'
      address.account_type  = BankPayments::SwedbankExport::AccountType::DEPOSIT_ACCOUNT
      address.cost_carrier  = BankPayments::SwedbankExport::CostResponsibility::OWN_EXPENSES
      address.priority      = BankPayments::SwedbankExport::Priority::NORMAL

      expect(address.to_s).to \
        eq '30000001VIRKESVÄGEN 12 120 30 STOCKHOLM                                  0SE 2 0'
    end
  end

  context "with a bank record" do
    subject { BankPayments::SwedbankExport::BankRecord }

    it "saves BIC (SWITFT) and IBAN numbers" do
      bank = subject.new
      bank.serial_number = 1
      bank.bank_id       = 'HELSFIHH'
      bank.account       = '102738'
      bank.name          = 'Helsingfors Sparbank'
      expect(bank.to_s).to eq '40000001HELSFIHH    102738                        HELSINGFORS SPARBANK          '
    end
  end

  context "with a credit memo record" do
    subject { BankPayments::SwedbankExport::CreditMemoRecord }

    let(:credit_memo) do
      credit_memo = subject.new

      credit_memo.serial_number       = 1
      credit_memo.reference_msg       = 'Invoice 25589-4'
      credit_memo.amount_sek          = 99.90
      credit_memo.amount_foreign      = 10.54
      credit_memo.currency_code       = 'EUR'
      credit_memo.date                =  Date.new(2016,11,12)

      credit_memo
    end

    it "generates correct a correct row" do
      expect(credit_memo.to_s).to eq \
        '50000001INVOICE 25589-4          0000000999-          EUR161112  000000000105M  '
    end

    it "sets special characters at pos. 44 and 78 for identification" do
      expect(credit_memo.to_s[44-1]).to eq '-'
      expect(credit_memo.to_s[78-1]).to eq 'M'
    end

    it "handles negative amounts correctly (by ignoring them)" do
      credit_memo = subject.new
      credit_memo.amount_sek          = -99.90
      credit_memo.amount_foreign      = -10.54
      credit_memo.currency_code       = 'EUR'

      expect(credit_memo.amount_sek).to     eq '999-'
      expect(credit_memo.amount_foreign).to eq '105M'
      expect(credit_memo.currency_code).to  eq 'EUR'
    end
  end

  context "with a payment post" do
    subject { BankPayments::SwedbankExport::PaymentRecord }

    let(:payment_record) do
      r = subject.new

      r.serial_number   =  1
      r.reference_msg   =  'Payment for secret deal 2 - with too long info'
      r.amount_sek      =  100_000
      r.amount_foreign  =  1_189_104.93
      r.currency_code   =  'JPY'
      r.date            =  Date.new(2016,8,5)

      r
    end

    it "sets the fields correctly" do
      expect(payment_record.serial_number).to  eq '1'
      expect(payment_record.reference_msg).to  eq 'PAYMENT FOR SECRET DEAL 2'
      expect(payment_record.amount_sek).to     eq '10000000'
      expect(payment_record.amount_foreign).to eq '118910493'
      expect(payment_record.currency_code).to  eq 'JPY'
      expect(payment_record.date).to           eq '160805'
    end

    it "serializes correctly" do
      expect(payment_record.to_s).to eq \
        '60000001PAYMENT FOR SECRET DEAL 200010000000          JPY160805  0000118910493  '
    end

    it "does have usual valules at pos. 44 and 78, compared with credit memos" do
      expect(payment_record.to_s[44-1]).to eq '0'
      expect(payment_record.to_s[78-1]).to eq '3'
    end
  end

  context "with the national bank reason" do
    subject { BankPayments::SwedbankExport::ReasonRecord }
    it "sets the code at the right place" do
      reason = subject.new
      reason.serial_number = 1
      reason.code          = 101

      expect(reason.to_s).to eq \
        '70000001101                                                                     '
    end
  end

  context 'with reconciliation' do
    subject { BankPayments::SwedbankExport::ReconciliationRecord }
    it "creates a regular line correctly" do
      rec = subject.new
      rec.account = '6381040'
      rec.sum_amount_sek       = 100.45
      rec.sum_amount_foreign,  = 10.58
      rec.total_beneficiaries, = 1
      rec.total_records,       = 4
      expect(rec.to_s).to eq \
        "906381040000000010045          000000000001000000000004        000000000001058  "
    end

    it "handles negative totals according to specification" do
      rec = subject.new
      rec.account = '6381040'
      rec.sum_amount_sek       = -100.45
      rec.sum_amount_foreign,  = -10.58
      rec.total_beneficiaries, = 1
      rec.total_records,       = 4
      expect(rec.to_s).to eq \
        "90638104000000001004N          000000000001000000000004        00000000000105Q  "
    end
  end
end