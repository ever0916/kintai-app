require 'spec_helper'

describe User do
  fixtures :users

  describe "with validation" do
    describe "有効な値" do
      it "有効な値" do
        @user = User.new(:name => "test",:email => "a@ex.jp",:password => "password")
        @user.should be_valid
      end
    end

    describe "空の名前は許可しないこと" do
      it "空の名前は許可しない" do
        @user = User.new(:name => nil,:email => "a@ex.jp",:password => "password")
        @user.should be_invalid
      end
    end

    describe "emailがdeviseのvalidetion形式にそぐわないなら無効であること" do
      it "emailがdeviseのvalidetion形式にそぐわないなら無効" do
        @user = User.new(:name => "test",:email => "a.ex.jp",:password => "password")
        @user.should be_invalid
      end
    end

    describe "空のemailは許可しないこと" do
      it "空のemailは許可しない" do
        @user = User.new(:name => "test",:email => nil,:password => "password")
        @user.should be_invalid
      end
    end

    describe "emailは一意であること" do
      it "emailは一意でなければばらない" do
        @user = User.new(:name => "test",:email => User.first.email,:password => "password")
        @user.should be_invalid
      end
    end

    describe "パスワードが8文字以外なら無効であること" do
      it "パスワードが8文字未満なら無効" do
        @user = User.new(:name => "test",:email => "a@ex.jp",:password => "passwor")
        @user.should be_invalid
      end
      it "パスワードが8文字を超える場合無効" do
        @user = User.new(:name => "test",:email => "a@ex.jp",:password => "passwordd")
        @user.should be_invalid
      end
    end

    describe "全角パスワードは有効、特殊文字有効であること" do
      it "全角パスワードは有効、特殊文字有効" do
        @user = User.new(:name => %Q{aa!"'a},:email => "a@ex.jp",:password => "パスワードパスワ")
        @user.should be_valid
      end
    end
  end

  describe "with DB" do
    describe "idは一意であること" do
      it "idは一意でなければならない" do
        expect do
          @user = User.new(:id => User.first.id,:name => "test",:email => "a@ex.jp",:password => "password")
          @user.save!
        end.to raise_error(ActiveRecord::StatementInvalid)#( ActiveRecord::RecordNotUnique ) http://pgnote.net/?p=1668の問題があるので、書き方を少し変えてる
      end
    end

    describe "idが空なら一意な値が自動で割り振られること" do
      it "idが空であれば一意な値が自動で割り振られる" do
        @user = User.new(:name => "test",:email => "a@ex.jp",:password => "password")
        @user.save

        User.last.id.should_not be_nil
      end
    end

    describe "名前は一意であること" do
      it "名前は一意でなければばらない" do
        expect do
          @user = User.new(:name => User.first.name,:email => "a@ex.jp",:password => "password")
          @user.save!
        end.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end
end
