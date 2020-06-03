
# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class BCryptJTest < Test::Unit::TestCase

  PASSWORD_BCRYPTED = '$2a$10$PtSNGlLXC5mgTrTcTioJuezprtYzfsrX3OYsc.4/8wNWPIJVxS28u'

  def test_bcrypt_j

    # Test the Java reimplementation of the bcrypt gem

    # Compatibility of output
    assert   (BCrypt::Password.new(PASSWORD_BCRYPTED) == 'password')
    assert ! (BCrypt::Password.new(PASSWORD_BCRYPTED) == 'afd98fij')

    # Another one
    encode1 = BCrypt::Password.create('hello123').to_s
    assert encode1.start_with?('$2a$13$') # 13 matches BCrypt::BCRYPT_ROUNDS
    assert encode1 != PASSWORD_BCRYPTED
    assert encode1 =~ /\A\$\w+\$/ # general form
    time_to_check_two_passwords_in_ms = KApp.execution_time_ms do
      assert   (BCrypt::Password.new(encode1) == 'hello123')
      assert ! (BCrypt::Password.new(encode1) == 'afd98fij')
    end
    assert time_to_check_two_passwords_in_ms > 800 # as it's supposed to be slow

    # Encoding again shouldn't have the same output
    encode2 = BCrypt::Password.create('hello123').to_s
    assert encode2 != encode1

    # Check empty/bad passwords don't work
    assert_raise(RuntimeError) { BCrypt::Password.create('') }
    assert_raise(RuntimeError) { BCrypt::Password.create(nil) }
    assert_raise(RuntimeError) { BCrypt::Password.create({:pants => :yes}) }

    # Check non-ASCII passwords work
    encode_na = BCrypt::Password.create('abc日本語').to_s
    assert encode_na != PASSWORD_BCRYPTED
    assert encode_na != encode1
    assert   (BCrypt::Password.new(encode_na) == 'abc日本語')
    assert ! (BCrypt::Password.new(encode_na) == 'abc???')  # old version of library had security flaw which converted non-ASCII chars to ?

    # Check configuration
    assert BCrypt::BCRYPT_ROUNDS > Java::OrgHaploCommonUtils::BCrypt::GENSALT_DEFAULT_LOG2_ROUNDS

    # Can create with smaller numbers of rounds, and it's quicker
    encode_lowrounds = BCrypt::Password.create('hello1234', 6).to_s
    time_to_check_lowrounds_in_ms = KApp.execution_time_ms do
      assert (BCrypt::Password.new(encode_lowrounds) == 'hello1234')
    end
    assert time_to_check_lowrounds_in_ms < 100

  end

end

