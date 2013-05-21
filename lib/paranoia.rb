module Paranoia
  def self.included(base)
    base.extend ClassMethods
    base.class_exec do
      default_scope { where(deleted_at: nil) }
    end
  end

  def destroy
    run_callbacks(:destroy) { delete }
  end

  def destroy!
    ActiveRecord::Base.instance_method(:destroy).bind(self).call
  end

  def delete
    return if new_record? or destroyed?
    update_column :deleted_at, Time.now
  end

  def delete!
    ActiveRecord::Base.instance_method(:delete).bind(self).call
  end

  def restore!
    update_column :deleted_at, nil
  end

  def destroyed?
    !!deleted_at
  end
  alias deleted? destroyed?

  def persisted?
    !new_record?
  end

  module ClassMethods
    def with_deleted
      all.tap { |r| r.default_scoped = false }
    end

    def only_deleted
      with_deleted.where.not(deleted_at: nil)
    end
  end
end
