class League
  include Mongoid::Document
  include ActiveModel::ForbiddenAttributesProtection
  field :name
  field :age_division
  field :season
  field :sport
  field :start_date, type: Date, default: 5.weeks.from_now.to_date
  field :end_date, type: Date, default: 15.weeks.from_now.to_date
  field :needs_standings_update, type: Boolean
  field :player_limit, type: Hash, default: {}
  field :price, type: Integer
  field :registration_open, type: Date, default: 2.weeks.from_now.to_date
  field :registration_close, type: Date, default: 4.weeks.from_now.to_date
  field :description, type: String

  # Options
  field :require_grank, type: Boolean, default: false
  field :allow_self_rank, type: Boolean, default: true
  field :allow_pairs, type: Boolean, default: true
  field :core_type
  field :eos_tourney, type: Boolean, default: true
  field :mst_tourney, type: Boolean, default: false

  has_many :teams, order: {league_rank: :asc}
  has_many :registrations
  has_and_belongs_to_many :commissioners, class_name: "User", foreign_key: :commissioner_ids, inverse_of: nil
  has_and_belongs_to_many :comped_groups, class_name: "CompGroup", inverse_of: nil
  has_and_belongs_to_many :comped_players, class_name: "User", inverse_of: nil

  validates :name, :presence => true
  validates :price, :numericality => { integer_only: true, greater_than: 0, less_than: 250, allow_blank: false  }
  validates :age_division, :inclusion => { in: %w(adult juniors) }
  validates :season, :inclusion => { in: %w(fall winter spring summer saturday) }
  validates :sport, :inclusion => { in: %w(ultimate goaltimate) }

  scope :past,    -> { where(:end_date.lt => Date.today).order_by(start_date: :desc) }
  scope :future,  -> { where(:registration_open.gt => Date.today).order_by(start_date: :desc) }
  scope :current, -> { where(:registration_open.lte => Date.today, :end_date.gte => Date.today).order_by(start_date: :desc) }

  def registration_open?
    return false if registration_open.nil? || registration_close.nil?

    open_time = registration_open.to_time.in_time_zone

    registration_open.to_time.in_time_zone.change(hour: 12).past? && registration_close.to_time.in_time_zone.end_of_day.future?
  end

  def started?
    start_date.beginning_of_day < Time.now
  end

  def comped?(user)
    return true if comped_player_ids.include? user._id
    return true if comped_groups.collect(&:member_ids).flatten.include? user._id
    false
  end

  def update_standings!
    # Update stats and sort the league
    team_cache = teams.to_a
    team_cache.each { |t| t.update_stats }.sort!.reverse!

    # Apply ranks, handle ties
    rank = 0
    team_cache.each_with_index do |this_team, order|
      unless (this_team <=> team_cache[order-1]) == 0
        rank += 1
      end

      this_team.league_rank = rank
      this_team.save
    end
  end

  def registration_for user
    registrations.where({user_id: user._id}).first
  end
end
