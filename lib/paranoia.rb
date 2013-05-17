module Paranoia
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def paranoid?; true; end

    def with_deleted
      all.tap { |r| r.default_scoped = false }
    end

    def only_deleted
      with_deleted.where.not(deleted_at: nil)
    end
  end

  def destroy
    run_callbacks(:destroy) { delete }
  end

  def delete
    return if destroyed? || new_record?
    update_column :deleted_at, Time.now
  end

  def restore!
    update_column :deleted_at, nil
  end

  def destroyed?
    !!deleted_at
  end
  alias deleted? destroyed?
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    alias destroy! destroy
    alias delete!  delete
    include Paranoia
    default_scope { where(deleted_at: nil) }
  end

  def self.paranoid?; false; end
  def paranoid?; self.class.paranoid?; end

  # Override the persisted method to allow for the paranoia gem.
  # If a paranoid record is selected, then we only want to check
  # if it's a new record, not if it is "destroyed".
  def persisted?
    paranoid? ? !new_record? : super
  end
end
