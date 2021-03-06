class MemberLocation < ActiveRecord::Base
  default_scope { where updated: true }

  belongs_to :member
  has_one :membership_detail, through: :member

  scope :displayed, -> { where updated: true }

  scope :search, -> (search) {
    where('address LIKE ?', "%#{search}%") if search.present?
  }

  validates :member_id, presence: true

  geocoded_by :address_fields
  after_validation :geocode, if: ->(obj) { obj.longitude.blank? or ( obj.address.present? and obj.address_changed? ) }

  def address_fields
    [address, postcode].compact.join(', ')
  end

  # x = MemberLocation.find_by(member_id: 1857)
  # latlng = Geocoder.coordinates("#{x.address.gsub(/\n/, '')}+#{x.postcode}")
  # x.update_attributes(latitude: latlng[0], longitude: latlng[1])
  # x.save!
  def self.batch_geocode
    #where('latitude is null').find_in_batches(batch_size: 100) do |group|
    # sleep(10)
    # group.each { |x| x.save! }
    #end
    #where('postcode != "" and updated_at < "2015-07-30"').find_in_batches(batch_size: 100) do |group|
    where('postcode != "" and updated = ?', true).find_in_batches(batch_size: 100) do |group|
      group.each do |x|
        latlng = Geocoder.coordinates("#{x.address.gsub(/\n/, '')}+#{x.postcode}") unless x.postcode.blank?
        latlng = Geocoder.coordinates("#{x.county}+#{x.postcode}") unless latlng.present? || ( x.county.blank? && x.postcode.blank? )
        if latlng.present?
          x.update_attributes(latitude: latlng[0], longitude: latlng[1])
          x.save!
        end
        sleep(2)
      end
    end
  end

  def self.grouped_county_and_town_for_select(show_all)
    locations = MemberLocation.locations_for_select(show_all)
    MemberLocation.make_hash_from_locations(locations)
  end

  def self.locations_for_select(show_all)
    unless show_all
      MemberLocation.where("town <> '' AND county <> ''").joins(:membership_detail).where("membership_details.in_practice = ? AND membership_details.is_admin = ? AND membership_details.membership_class <> ''", 'Y', 'N').pluck(:town, :county).uniq
    else
      MemberLocation.where("town <> '' AND county <> ''").joins(:membership_detail).where("membership_details.membership_class <> ''").pluck(:town, :county).uniq
    end
  end

  def self.make_hash_from_locations(locations)
    hash = locations.each_with_object({}) do |town_and_county, hash|
      hash[town_and_county.last] = [] if hash[town_and_county.last].nil?
      hash[town_and_county.last] << town_and_county.first
    end
    MemberLocation.sort_hash_of_arrays(hash)
  end

  def self.sort_hash_of_arrays(hash)
    # sort the arrays
    hash.each do |k,v|
      hash[k] = v.sort
    end
    # sort the keys
    hash.sort
  end

  def self.county_and_town_for_select(show_all)
    locations = MemberLocation.locations_for_select(show_all)
    locations = locations.sort_by{|x| x.first }
    locations.map{|x| "#{x.first} (#{x.last})"}
  end

end
