# encoding: utf-8

User.class_eval do
  has_one :profile, inverse_of: :user, dependent: :destroy

  has_many :user_groups, dependent: :destroy
  has_many :groups, through: :user_groups

  validates :language, inclusion: { in: I18n.available_locales.map(&:to_s) }

  delegate :initials, :full_name, to: :profile

  after_create :create_profile!
  after_create :setup_default_groups

  accepts_nested_attributes_for :profile
  accepts_nested_attributes_for :groups

  before_validation do
    self.language ||= I18n.default_locale.to_s
  end

  scope :finder, (lambda do |q|
    string = %w[profiles.last_name profiles.first_name profiles.middle_name email].join("||' '||")
    joins(:profile).where("(#{string}) LIKE ?", "%#{q}%").order("profiles.last_name")
  end)

  def as_json(_options)
    { id: id, text: full_name_with_email }
  end

  def to_s
    full_name
  end

  def full_name_with_email
    [full_name, email].join(" ")
  end

  def self.superadmins
    Group.superadmins.users
  end

  def self.support
    Group.support.users
  end

  def self.experts
    Group.experts.users
  end

  def self.reregistrators
    Group.reregistrators.users
  end

  def mailsender?
    groups.where(name: 'mailsenders').any?
  end

  private

  def setup_default_groups
    user_groups.where(group_id: Group.authorized.id).first_or_create!
    true
  end
end
