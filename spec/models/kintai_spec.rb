require 'spec_helper'

#ユニーク制約はDB側に設定すること。(２回早くボタンを押されるとvalidationをすり抜けて稀に通るため)

describe Kintai do
  fixtures :kintais

  describe "with validation" do
    describe "有効な値" do
      it "有効な値" do
        @kintai = Kintai.new(:t_syukkin => Time.now,:t_taikin => Time.now)
        @kintai.should be_valid
      end
    end

    describe "現在時刻を超えていなければ有効であること" do
      it "退勤時間が現在時刻を超えている" do
        @kintai = Kintai.new(:t_syukkin => Time.now,:t_taikin => Time.now + 1)
        @kintai.should be_invalid
      end

      it "退勤時刻は空を許可する" do
        @kintai = Kintai.new(:t_syukkin => Time.now,:t_taikin => nil)
        @kintai.should be_valid
      end
    end

    describe "出勤時間が退勤時間を超えていなければ有効であること" do
      it "出勤時刻が退勤時刻を超えている" do
        @kintai = Kintai.new(:t_syukkin => Time.now,:t_taikin => Time.now - 1)
        @kintai.should be_invalid
      end
    end

    describe "出勤時間は空を許可せず、退勤時間は空を許可すること" do
      it "出勤時刻は空を許可しない" do
        @kintai = Kintai.new(:t_syukkin => nil,:t_taikin => Time.now)
        @kintai.should be_invalid
      end
      it "退勤時刻は空を許可する" do
        @kintai = Kintai.new(:t_syukkin => Time.now,:t_taikin => nil)
        @kintai.should be_valid
      end
    end
  end

  describe "with DB" do
    describe "idは一意であること" do
      it "idは一意でなければならない" do
        expect do
          @kintai = Kintai.new(:id => Kintai.first.id, :t_syukkin => Time.now,:t_taikin => Time.now)
          @kintai.save!
        end.to raise_error( ActiveRecord::StatementInvalid )
      end
    end

    describe "idが空なら一意な値が自動で割り振られること" do
      it "idが空であれば一意な値が自動で割り振られる" do
        @kintai = Kintai.new(:t_syukkin => Time.now,:t_taikin => Time.now)
        @kintai.save

        Kintai.last.id.should_not be_nil
      end
    end
  end

end
