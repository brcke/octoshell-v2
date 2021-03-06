require 'main_spec_helper'
require 'receive_emails/lmtp_server'
module ReceiveEmails
  describe "ReceiveEmails", type: :mailer do
    before(:all) do
      @server = ReceiveEmails.lmtp_server
      Thread.new { @server.start }
      @user = create_admin
      @mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body 'Ticket body'
        add_file filename: 'somefile.rb', content: File.read($0)
      end
      @mail.from = @user.email
    end
    after(:all) do
      @server.stop
    end

    it 'creates new ticket without text body' do
      @mail_without_body = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        add_file filename: 'somefile.rb', content: File.read($PROGRAM_NAME)
      end
      @mail_without_body.from = @user.email
      expect { to_exim @mail_without_body }.to change{ Support::Ticket.count }.by 1
      expect(Support::Ticket.last).to have_attributes(reporter: @user,
                                                      subject: 'Ticket title')
      @ticket = Support::Ticket.last
      expect(@ticket.attachment.url.split('/').last).to eq 'somefile.rb'
    end

    it 'creates new ticket with one attachment' do
      expect { to_exim @mail }.to change { Support::Ticket.count }.by 1
      expect(Support::Ticket.last).to have_attributes(reporter: @user,
                                                      message: 'Ticket body',
                                                      subject: 'Ticket title')
      @ticket = Support::Ticket.last
      expect(@ticket.attachment.url.split('/').last).to eq 'somefile.rb'
    end

    it 'creates new ticket with 2 attachments in Russian' do
      mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body 'Ticket body'
        add_file filename: 'eng', content: File.read($0)
        add_file filename: 'eng2', content: File.read($0)
      end
      mail.from = @user.email

      expect { to_exim mail }.to change { Support::Ticket.count }.by 1
      expect(Support::Ticket.last).to have_attributes(reporter: @user,
                                                      message: 'Ticket body',
                                                      subject: 'Ticket title')
      ticket = Support::Ticket.last
      expect(ticket.attachment.url.split('/').last).to eq 'attachments.zip'
    end


    it 'creates new ticket with one attachment in Russian' do
      @mail_ru = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body 'Ticket body'
        add_file filename: 'по-русски', content: File.read($0)
      end
      @mail_ru.from = @user.email

      expect { to_exim @mail_ru }.to change { Support::Ticket.count }.by 1
      expect(Support::Ticket.last).to have_attributes(reporter: @user,
                                                      message: 'Ticket body',
                                                      subject: 'Ticket title')
      @ticket = Support::Ticket.last
      expect(@ticket.attachment.url.split('/').last).to eq 'po-russki'
    end


    it 'creates new ticket without attachment' do
      @mail_without_attachment = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body 'Ticket body'
      end
      @mail_without_attachment.from = @user.email
      expect { to_exim @mail_without_attachment }.to change { Support::Ticket.count }.by 1
      expect(Support::Ticket.last).to have_attributes(reporter: @user,
                                                      message: 'Ticket body',
                                                      subject: 'Ticket title')
    end

    it "creates new ticket without attachment with Auto-Submitted == 'no'" do
      @mail_without_attachment = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body 'Ticket body'
      end
      @mail_without_attachment.header['Auto-Submitted'] = 'no'
      @mail_without_attachment.from = @user.email
      expect { to_exim @mail_without_attachment }.to change { Support::Ticket.count }.by 1
      expect(Support::Ticket.last).to have_attributes(reporter: @user,
                                                      message: 'Ticket body',
                                                      subject: 'Ticket title')
    end



    it 'does not create new ticket with Auto-Submitted header' do
      @mail.headers['Auto-Submitted'] = 'auto-replied'
      @mail.from = 'andrey@andrey-vostro-3558'
      @mail.to = 'andrey@andrey-vostro-3558'
      @mail.subject = 'I am auto-submitted'
      expect { to_exim @mail }.to change{ Support::Ticket.count }.by 0
    end

    it 'does not create new ticket' do
      @mail.from = 'notexist@mail.ru'
      expect { to_exim @mail }.to change{ Support::Ticket.count }.by 0
    end

    it 'creates new reply to ticket via email without attachment' do
      ticket = create(:ticket)
      support = create_support
      ticket.replies.create!(message: 'hello', author: support)
      new_body = ActionMailer::Base.deliveries.last.body.to_s.gsub('-' * Support.dash_number,  '-' * Support.dash_number + 'I answer hello')
      mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body new_body
      end
      mail.from = support.email
      expect { to_exim mail }.to change{ Support::Reply.count }.by 1
      expect(Support::Reply.last).to have_attributes(author: support,
                                                     message: 'I answer hello',
                                                     ticket: ticket)
    end

    it 'does not creates new reply for foreign ticket ' do
      ticket = create(:ticket)
      user = create(:user)
      support = create_support
      ticket.replies.create!(message: 'hello', author: support)
      new_body = ActionMailer::Base.deliveries.last.body.to_s.gsub('-' * Support.dash_number,  '-' * Support.dash_number + 'I answer hello')
      mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body new_body
      end
      mail.from = user.email
      expect { to_exim mail }.to change{ Support::Reply.count }.by 0
    end


    it 'does not create new reply to ticket via email without attachment and with empty reply' do
      ticket = create(:ticket)
      support = create_support(language: 'en')
      ticket.replies.create!(message: 'hello', author: support)
      new_body = ActionMailer::Base.deliveries.last.body.to_s
      mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body new_body
      end
      mail.from = support.email
      expect { to_exim mail }.to change{ Support::Reply.count }.by 0
      puts ActionMailer::Base.deliveries.last.inspect.yellow
    end

    it 'creates new reply to ticket via email with attachment' do
      ticket = create(:ticket)
      support = create_support
      ticket.replies.create!(message: 'hello', author: support)
      new_body = ActionMailer::Base.deliveries.last.body.to_s.gsub('-' * Support.dash_number,  '-' * Support.dash_number + 'I answer hello')
      mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body new_body
        add_file filename: 'somefile.rb', content: File.read($0)
      end
      mail.from = support.email
      ticket.close
      expect { to_exim mail }.to change{ Support::Reply.count }.by 1
      expect(Support::Reply.last).to have_attributes(author: support,
                                                     message: 'I answer hello',
                                                     ticket: ticket)
      expect(Support::Ticket.last.state).to eq 'answered_by_support'
      expect(Support::Reply.last.attachment.url.split('/').last).to eq 'somefile.rb'
    end

    it 'creates new reply to ticket via email with attachment' do
      ticket = create(:ticket)
      support = create_support
      ticket.replies.create!(message: 'hello', author: support)
      new_body = ActionMailer::Base.deliveries.last.body.to_s.gsub('-' * Support.dash_number,  '-' * Support.dash_number + 'I answer hello')
      mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body new_body
        add_file filename: 'somefile.rb', content: File.read($0)
      end
      mail.from = support.email
      expect { to_exim mail }.to change{ Support::Reply.count }.by 1
      expect(Support::Reply.last).to have_attributes(author: support,
                                                     message: 'I answer hello',
                                                     ticket: ticket)
      expect(Support::Reply.last.attachment.url.split('/').last).to eq 'somefile.rb'
    end

    it 'creates new reply to ticket via email with 2 attachments' do
      ticket = create(:ticket)
      support = create_support
      ticket.replies.create!(message: 'hello', author: support)
      new_body = ActionMailer::Base.deliveries.last.body.to_s.gsub('-' * Support.dash_number,  '-' * Support.dash_number + 'I answer hello')
      mail = Mail::Message.new do
        to 'support@octoshell.ru'
        subject 'Ticket title'
        body new_body
        add_file filename: 'somefile.rb', content: File.read($0)
        add_file filename: 'somefile2W.rb', content: File.read($0)
      end
      mail.from = support.email
      expect { to_exim mail }.to change{ Support::Reply.count }.by 1
      expect(Support::Reply.last).to have_attributes(author: support,
                                                     message: 'I answer hello',
                                                     ticket: ticket)
      expect(Support::Reply.last.attachment.url.split('/').last).to eq 'attachments.zip'
    end
  end
end
