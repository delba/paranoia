gem 'minitest', '4.7.4'
require 'minitest/autorun'
require 'active_record'
require_relative '../lib/paranoia'

class ParanoiaTest < Minitest::Unit::TestCase
  i_suck_and_my_tests_are_order_dependent!

  def test_paranoid_models_to_param
    model = ParanoidModel.new
    model.save
    to_param = model.to_param

    model.destroy

    refute_nil model.to_param
    assert_equal to_param, model.to_param
  end

  def test_destroy_behavior_for_plain_models
    model = PlainModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_nil model.deleted_at

    assert_equal 0, model.class.count
    assert_equal 0, model.class.unscoped.count
  end

  def test_destroy_behavior_for_paranoid_models
    model = ParanoidModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    refute_nil model.deleted_at

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count
  end

  def test_scoping_behavior_for_paranoid_models
    ParanoidModel.unscoped.delete_all
    parent1 = ParentModel.create
    parent2 = ParentModel.create
    p1 = ParanoidModel.create(parent_model: parent1)
    p2 = ParanoidModel.create(parent_model: parent2)
    p1.destroy
    p2.destroy
    assert_equal 0, parent1.paranoid_models.count
    assert_equal 1, parent1.paranoid_models.only_deleted.count
    p3 = ParanoidModel.create(parent_model: parent1)
    assert_equal 2, parent1.paranoid_models.with_deleted.count
    assert_equal [p1,p3], parent1.paranoid_models.with_deleted
  end

  def test_destroy_behavior_for_featureful_paranoid_models
    model = get_featureful_model
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    refute_nil model.deleted_at.nil?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count
  end

  # Regression test for #24
  def test_chaining_for_paranoid_models
    scope = FeaturefulModel.where(name: "foo").only_deleted
    assert_equal "foo", scope.where_values_hash[:name]
    assert_equal 2, scope.where_values.count
  end

  def test_only_destroyed_scope_for_paranoid_models
    model = ParanoidModel.new
    model.save
    model.destroy
    model2 = ParanoidModel.new
    model2.save

    assert_equal model, ParanoidModel.only_deleted.last
    refute_includes ParanoidModel.only_deleted, model2
  end

  def test_default_scope_for_has_many_relationships
    parent = ParentModel.create
    assert_equal 0, parent.related_models.count

    child = parent.related_models.create
    assert_equal 1, parent.related_models.count

    child.destroy
    refute_nil child.deleted_at

    assert_equal 0, parent.related_models.count
    assert_equal 1, parent.related_models.unscoped.count
  end

  def test_default_scope_for_has_many_through_relationships
    employer = Employer.create
    employee = Employee.create
    assert_equal 0, employer.jobs.count
    assert_equal 0, employer.employees.count
    assert_equal 0, employee.jobs.count
    assert_equal 0, employee.employers.count

    job = Job.create employer: employer, employee: employee
    assert_equal 1, employer.jobs.count
    assert_equal 1, employer.employees.count
    assert_equal 1, employee.jobs.count
    assert_equal 1, employee.employers.count

    employee2 = Employee.create
    job2 = Job.create employer: employer, employee: employee2
    employee2.destroy
    assert_equal 2, employer.jobs.count
    assert_equal 1, employer.employees.count

    job.destroy
    assert_equal 1, employer.jobs.count
    assert_equal 0, employer.employees.count
    assert_equal 0, employee.jobs.count
    assert_equal 0, employee.employers.count
  end

  def test_delete_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.delete
    assert_nil model.instance_variable_get(:@callback_called)
  end

  def test_destroy_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.destroy
    assert model.instance_variable_get(:@callback_called)
  end

  def test_restore
    model = ParanoidModel.new
    model.save
    id = model.id
    model.destroy

    assert model.destroyed?

    model = ParanoidModel.only_deleted.find(id)
    model.restore!
    model.reload

    refute model.destroyed?
  end

  def test_real_destroy
    model = ParanoidModel.new
    model.save
    model.destroy!

    refute ParanoidModel.unscoped.exists?(model.id)
  end

  def test_real_delete
    model = ParanoidModel.new
    model.save
    model.delete!

    refute ParanoidModel.unscoped.exists?(model.id)
  end

private

  def get_featureful_model
    FeaturefulModel.new(name: "not empty")
  end
end

# Migrations

DB_FILE = 'tmp/test_db'

FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: DB_FILE

ActiveRecord::Migration.class_exec do
  self.verbose = false

  create_table :parent_models do |t|
    t.datetime :deleted_at
  end

  create_table :paranoid_models do |t|
    t.references :parent_model
    t.datetime :deleted_at
  end

  create_table :featureful_models do |t|
    t.string :name
    t.datetime :deleted_at
  end

  create_table :plain_models do |t|
    t.datetime :deleted_at
  end

  create_table :callback_models do |t|
    t.datetime :deleted_at
  end

  create_table :related_models do |t|
    t.references :parent_model
    t.datetime :deleted_at
  end

  create_table :employers do |t|
    t.datetime :deleted_at
  end

  create_table :employees do |t|
    t.datetime :deleted_at
  end

  create_table :jobs do |t|
    t.references :employer
    t.references :employee
    t.datetime :deleted_at
  end
end

# Helper classes

class ParentModel < ActiveRecord::Base
  has_many :paranoid_models
end

class ParanoidModel < ActiveRecord::Base
  include Paranoia
  belongs_to :parent_model
end

class FeaturefulModel < ActiveRecord::Base
  include Paranoia
  validates :name, presence: true, uniqueness: true
end

class PlainModel < ActiveRecord::Base
end

class CallbackModel < ActiveRecord::Base
  include Paranoia
  before_destroy {|model| model.instance_variable_set :@callback_called, true }
end

class ParentModel < ActiveRecord::Base
  include Paranoia
  has_many :related_models
end

class RelatedModel < ActiveRecord::Base
  include Paranoia
  belongs_to :parent_model
end

class Employer < ActiveRecord::Base
  include Paranoia
  has_many :jobs
  has_many :employees, through: :jobs
end

class Employee < ActiveRecord::Base
  include Paranoia
  has_many :jobs
  has_many :employers, through: :jobs
end

class Job < ActiveRecord::Base
  include Paranoia
  belongs_to :employer
  belongs_to :employee
end
