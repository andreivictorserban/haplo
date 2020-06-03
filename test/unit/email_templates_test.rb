# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class EmailTemplatesTest < Test::Unit::TestCase

  # ----------------------------------------------------------------------------------------------------------------
  # invalid HTML
  def test_invalid_HTML
    t = create_template(:branding_html => "<p>WOOF")
    transfer = EmailTemplate::EditTransfer.new(t)
    assert_equal ["is not valid HTML"], transfer.errors[:branding_html]

    # But skip this check if the branding HTML is a global template which doesn't use any of the built in generation
    t = create_template(:branding_html => "%%USER_HTML_ONLY%%<p>WOOF")
    transfer = EmailTemplate::EditTransfer.new(t)
    assert_equal [], transfer.errors[:branding_html]

    # Check it's tweaked OK so that HTML passes the XML parser
    assert_equal '<img src="x" /><hr /><br /><br /><br /><hr /><p>test</p>', EmailTemplate.tweak_html('<img src="x"><hr><br><br ><br/><hr /><p>test</p>')
  end

  # ----------------------------------------------------------------------------------------------------------------
  # unrecognised interpolations
  def test_unrecognised_interpolations
    t = create_template(:header => "Dear %%WOOF%%")
    transfer = EmailTemplate::EditTransfer.new(t)
    assert_equal ["contains an invalid interpolation string (WOOF)"], transfer.errors[:header]
  end

  # ----------------------------------------------------------------------------------------------------------------
  # Basic sending and conversion
  def test_basic_send
    db_reset_test_data
    basic_send()
    basic_send(:plain)
    assert EmailTemplate::MAX_PLAIN_EQUIVALENT_LENGTH > (16*1024) # make sure it's a minimum lenght
    basic_send(:plain, EmailTemplate::MAX_PLAIN_EQUIVALENT_LENGTH * 2)

    # Test minimal template works sending to string email address
    t = create_template({})
    d_before = EmailTemplate.test_deliveries.size
    t.deliver(
      :to => 'test@example.com',
      :subject => 'Test Subject',
      :message => '<p>Message</p>'
    )
    assert_equal d_before + 1, EmailTemplate.test_deliveries.size
    assert_equal ['test@example.com'], EmailTemplate.test_deliveries.last.header.to

    # Test sending to user object
    t.deliver(
      :to => User.cache[41],
      :subject => 'Test Subject',
      :message => '<p>Message</p>'
    )
    assert_equal d_before + 2, EmailTemplate.test_deliveries.size
    assert_equal [RMail::Address.new('User 1 <user1@example.com>')], EmailTemplate.test_deliveries.last.header.to
  end

  def basic_send(format = :html, msg_size = 128, template_spec = {}, &check_body_block)
    message = template_spec.delete(:message_start) || ''
    while(message.length < msg_size)
      # Message includes an HTML entity
      message << '<p>Message &nbsp; AfterNbsp Message Message Message Message Message Message Message Message</p>'
    end
    t = create_template({
      :extra_css => 'some_css_class { color:red }',
      :branding_html => '<p>Branding HTML %%FEATURE_NAME%%</p>',
      :branding_plain => "===\nBRANDING PLAIN %%FEATURE_NAME%%\n===\n",
      :header => "<p>Header</p>",
      :footer => '<p>Footer</p>'
    }.merge(template_spec))
    d_before = EmailTemplate.test_deliveries.size
    t.deliver(
      :to => 'test@example.com',
      :subject => 'Test Subject',
      :message => message,
      :format => format,
      :interpolate => {'UNSUBSCRIBE_URL' => 'http://www.example.com/unsub', 'FEATURE_NAME' => 'Test Feature'}
    )
    # Get the sent email and check the basics
    assert_equal d_before + 1, EmailTemplate.test_deliveries.size
    sent = EmailTemplate.test_deliveries.last
    assert_equal ['test@example.com'], sent.header.to
    assert_equal ['bob@example.com'], sent.header.from
    assert_equal 'Test Subject', sent.header.subject

    # Which parts to expect?
    expect_html = (format != :plain)
    expect_plain = ((format == :plain) || (message.length < EmailTemplate::MAX_PLAIN_EQUIVALENT_LENGTH))
    expect_multipart = (expect_plain && expect_html)

    # Check parts
    assert_equal expect_multipart, sent.multipart?
    if expect_multipart
      had_plain = false
      had_html = false
      assert sent.multipart?
      assert_equal 'multipart/alternative', sent.header.content_type
      sent.body.each do |part|
        assert part.header['Content-Type'] =~ /; charset="utf-8"/
        case part.header.content_type
        when 'text/plain'
          assert had_plain == false
          check_plain(part.body, check_body_block)
          had_plain = true
        when 'text/html'
          assert had_html == false
          check_html(part.body.gsub("=\n",'').strip, check_body_block)
          had_html = true
        else
          assert false  # unrecognised part
        end
      end
      assert had_plain && had_html
    else
      # Single part only
      assert sent.header['Content-Type'] =~ /; charset="utf-8"/
      if expect_plain
        check_plain(sent.body, check_body_block)
        assert_equal 'text/plain', sent.header.content_type
      end
      if expect_html
        check_html(sent.body, check_body_block)
        assert_equal 'text/html', sent.header.content_type
      end
    end
  end
  def check_plain(text, check_body_block)
    if nil != check_body_block
      check_body_block.call(:plain, text)
      return
    end
    assert_match /BRANDING PLAIN Test Feature/, text
    assert_match /Header/, text
    assert_match /Footer/, text
    assert_match /Message   AfterNbsp/, text # entity decoded
    assert_match /unsubscribe/, text    # check the link was added
    assert !(text =~ /<p>/)
    assert !(text =~ /HTML/)
    assert !(text =~ /some_css_class/)
  end
  def check_html(text, check_body_block)
    if nil != check_body_block
      check_body_block.call(:html, text)
      return
    end
    assert_match /<p>Branding HTML Test Feature/, text
    assert_match /<p>Header/, text
    assert_match /<p>Footer/, text
    assert_match /<p>Message &nbsp;/, text  # entity is preserved
    assert_match /unsubscribe/, text    # check the link was added
    assert_match /some_css_class/, text
    assert !(text =~ /PLAIN/)
  end

  # ----------------------------------------------------------------------------------------------------------------
  # Test URLs without a URL scheme name has the application URL added

  def test_add_application_hostname_to_bad_urls
    url_base = KApp.url_base()
    assert url_base =~ /\Ahttps?:\/\/www\d+/
    [
      ['www.test.example.com', 'BASE/www.test.example.com'],
      ['/path/to/something.txt', 'BASE/path/to/something.txt'],
      ['path/to/something.txt', 'BASE/path/to/something.txt'],
      ['https://www9999.example.com', 'https://www9999.example.com'],
      ['http://www9999.example.com', 'http://www9999.example.com'],
      ['https://www9999.example.com/', 'https://www9999.example.com/'],
      ['https://www9999.example.com/path', 'https://www9999.example.com/path'],
      ['ftp://www9999.example.com/path', 'ftp://www9999.example.com/path'],
      ['mailto:test@example.com', 'mailto:test@example.com'],
      ['-mailto:test@example.com', 'BASE/-mailto:test@example.com']
    ].each do |url, expected_url|
      expected_url = expected_url.gsub('BASE', url_base)
      # Plain
      html = %Q!<p class='link1'><a href="#{url}">Description of URL</a></p>!
      check_html_to_plain(html, "  Description of URL\n    #{expected_url}\n")
      # HTML
      [
        html, # normal links
        %Q!<p class='button'><a href="#{url}">Description of URL</a></p>! # button has different code
      ].each do |body_html|
        basic_send(:html, 1, {:message_start => body_html}) do |kind, body|
          assert body.include?(expected_url)
        end
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------------------
  # Test HTML email templates which use the branding HTML for the entire message

  def test_entire_html_branding
    expected_text = ['Click here to unsubscribe', 'HHH1', 'FFF2']
    parts_seen = []
    basic_send(:html, 1, {
      :branding_html => '%%USER_HTML_ONLY%%<html><body><h1>Hello</h1>%%MESSAGE%%</body></html>',
      :header => "<p>HHH1</p>",
      :footer => '<p>FFF2</p>'
    }) do |kind, body|
      parts_seen << kind
      expected_text.each do |t|
        body.include?(t)
      end
      if kind == :html
        assert_equal "<html><body><h1>Hello</h1><p>HHH1</p><p>Message &nbsp; AfterNbsp Message Message Message Message Message Message Message Message</p><p>FFF2</p><p class=3D\"action\">Click here to unsubscribe: <a href=3D\"http://www.example.com/unsub\">Unsubscribe</a></p></body></html>", body.gsub("=\n",'').strip
      end
    end
    assert parts_seen.include?(:html)
    assert parts_seen.include?(:plain)
  end

  # ----------------------------------------------------------------------------------------------------------------
  # Text rendering HTML into plain text
  def test_html_to_plain
    # paragraph
    html = <<__E
      <p>This is a long paragraph which should get wrapped to 76 chars, with the rest of the characters added on a new line.</p>
__E
    check_html_to_plain(html, "This is a long paragraph which should get wrapped to 76 chars, with the rest\nof the characters added on a new line.\n")

    # description
    html = <<__E
      <p>Something</p>
      <p class='description'>Description: one tab indent, no blank line preceding, so when word wrapping occurs the indent should be maintained.</p>
      <p class="link0"><a href="http://host...">A nice link</a></p>
      <p class="description">Description of link.</p>
__E
    check_html_to_plain(html, "Something\n  Description: one tab indent, no blank line preceding, so when word\n  wrapping occurs the indent should be maintained.\n\nA nice link\n  http://host...\n  Description of link.\n")

    # Two paragraphs of text
    html = <<__E
      <p>Para 1</p><p>Para 2</p>
__E
    check_html_to_plain(html, "Para 1\n\nPara 2\n")

    # link 1
    html = <<__E
      <p class='link1'><a href="http://www.example.com">Description of URL</a></p>
__E
    check_html_to_plain(html, "  Description of URL\n    http://www.example.com\n")

    # link 2
    html = <<__E
      <p class="action">Click here to unsubscribe: <a href="http://www.example.com/...">Unsubscribe</a></p>
__E
    check_html_to_plain(html, "* Click here to unsubscribe:\n    http://www.example.com/...\n")

    # block quote
    html = <<__E
      <p>Para 1</p>
      <blockquote>Block quote should have a two-tab indent, a blank line preceding, and the line width reduced by two tabs</blockquote>
      <p>Para 2</p>
__E
    check_html_to_plain(html, "Para 1\n\n    Block quote should have a two-tab indent, a blank line preceding, and\n    the line width reduced by two tabs\n\nPara 2\n")

    # h1 (also tests underlining works when the block to be underlined wraps)
    html = <<__E
      <p>Para</p>
      <h1>Two blank lines preceding, text, then = chars to width of header to underline</h1>
__E
    check_html_to_plain(html, "Para\n\n\nTwo blank lines preceding, text, then = chars to width of header to\nunderline\n=========\n")

    # h2
    html = <<__E
      <p>Para</p>
      <h2>One blank line preceding, text, then - chars to width of header to underline</h2>
__E
    check_html_to_plain(html, "Para\n\nOne blank line preceding, text, then - chars to width of header to underline\n----------------------------------------------------------------------------\n")

    # test underlining works when the block to be underlined doesn't wrap
    html = <<__E
      <h2>One blank line preceding, text, then - chars to width of header to underline</h2>
__E
    check_html_to_plain(html, "One blank line preceding, text, then - chars to width of header to underline\n----------------------------------------------------------------------------\n")

    # nested elements - not valid HTML but make sure they produce something sensible
    html = <<__E
      <p>Top level<p>Second level<a href="www.example.com">Link</a></p></p>
__E
    check_html_to_plain(html, "Top levelSecond levelLink\n")

    # Bad HTML is ignored
    html = <<__E
      <p>Not bad</p>
      <p>Bad HTML here
__E
    check_html_to_plain(html, "\n")

  end

  def check_html_to_plain(html, expected)
    t = EmailTemplate.new
    assert_equal(expected, t.html_to_text("<body>#{html}</body>"))
  end

  # ----------------------------------------------------------------------------------------------------------------

  def create_template(params)
    t = EmailTemplate.new
    t.name = params[:name] || "t1"
    t.code = params[:code] || "test:email-template:t1"
    t.description = params[:description] || "d1"
    t.purpose = params[:purpose]
    t.from_email_address = params[:from_email_address] || "bob@example.com"
    t.from_name = params[:from_name] || "Bob"
    t.extra_css = params[:extra_css]
    t.branding_plain = params[:branding_plain]
    t.branding_html = params[:branding_html]
    t.header = params[:header]
    t.footer = params[:footer]
    t.in_menu = params[:in_menu] || true
    t
  end

end
