class ContactMessage
  include RocketCMS::Model

  apply_simple_captcha

  field :name, type: String
  field :email, type: String
  field :phone, type: String
  field :content, type: String

  validates_email_format_of :email, unless: 'email.blank?'

  if RocketCMS.configuration.contacts_message_required
    validates_presence_of :content
  end

  validate do
    if email.blank? && phone.blank?
      errors.add(:email, I18n.t('rs.no_contact_info'))
    end
  end

  RocketCMS.configuration.contacts_fields.each_pair do |fn, ft|
    field fn, type: ft
  end

  after_create do
    ContactMailer.new_message_email(self).deliver
  end

  rails_admin do
    navigation_label I18n.t('rs.settings')

    list do
      field :c_at
      field :name
      field :content
      field :email
      field :phone
      RocketCMS.configuration.contacts_fields.each_pair do |fn, ft|
        field fn
      end
    end
  end
end
