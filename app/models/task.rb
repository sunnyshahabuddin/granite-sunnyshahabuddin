# frozen_string_literal: true

class Task < ApplicationRecord
  RESTRICTED_ATTRIBUTES = %i[title task_owner_id assigned_user_id]
  belongs_to :assigned_user, foreign_key: "assigned_user_id", class_name: "User"
  belongs_to :task_owner, foreign_key: "task_owner_id", class_name: "User"
  validates :title, presence: true, length: { maximum: 50 }
  validates :slug, uniqueness: true
  validate :slug_not_changed
  has_many :comments, dependent: :destroy

  enum progress: { pending: "pending", completed: "completed" }
  enum status: { unstarred: "unstarred", starred: "starred" }

  before_create :set_slug
  MAX_TITLE_LENGTH = 125

  private

    def self.of_status(progress)
      if progress == :pending
        starred = pending.starred.order("updated_at DESC")
        unstarred = pending.unstarred.order("updated_at DESC")
      else
        starred = completed.starred.order("updated_at DESC")
        unstarred = completed.unstarred.order("updated_at DESC")
      end
      starred + unstarred
    end

    def set_slug
      title_slug = title.parameterize
      regex_pattern = "slug #{Constants::DB_REGEX_OPERATOR} ?"
      latest_task_slug = Task.where(
        regex_pattern,
        "#{title_slug}$|#{title_slug}-[0-9]+$"
      ).order("LENGTH(slug) DESC", slug: :desc).first&.slug
      slug_count = 0
      if latest_task_slug.present?
        slug_count = latest_task_slug.split("-").last.to_i
        only_one_slug_exists = slug_count == 0
        slug_count = 1 if only_one_slug_exists
      end
      slug_candidate = slug_count.positive? ? "#{title_slug}-#{slug_count + 1}" : title_slug
      self.slug = slug_candidate
    end

    def slug_not_changed
      if slug_changed? && self.persisted?
        errors.add(:slug, t("task.slug.immutable"))
      end
    end

    def test_task_count_increases_on_saving
      assert_difference ["Task.count"], 1 do
        create(:task)
      end
    end

    def test_task_should_not_be_valid_without_title
      @task.title = ""
      assert_not @task.valid?
    end

    def test_task_slug_is_parameterized_title
      title = @task.title
      @task.save!
      assert_equal title.parameterize, @task.slug
    end

    def test_incremental_slug_generation_for_tasks_with_duplicate_two_worded_titles
      first_task = Task.create!(title: "test task", assigned_user: @user, task_owner: @user)
      second_task = Task.create!(title: "test task", assigned_user: @user, task_owner: @user)

      assert_equal "test-task", first_task.slug
      assert_equal "test-task-2", second_task.slug
    end

    def test_incremental_slug_generation_for_tasks_with_duplicate_hyphenated_titles
      first_task = Task.create!(title: "test-task", assigned_user: @user, task_owner: @user)
      second_task = Task.create!(title: "test-task", assigned_user: @user, task_owner: @user)

      assert_equal "test-task", first_task.slug
      assert_equal "test-task-2", second_task.slug
    end

    def test_slug_generation_for_tasks_having_titles_one_being_prefix_of_the_other
      first_task = Task.create!(title: "fishing", assigned_user: @user, task_owner: @user)
      second_task = Task.create!(title: "fish", assigned_user: @user, task_owner: @user)

      assert_equal "fishing", first_task.slug
      assert_equal "fish", second_task.slug
    end

    def test_error_raised_for_duplicate_slug
      another_test_task = Task.create!(title: "another test task", assigned_user: @user, task_owner: @user)

      assert_raises ActiveRecord::RecordInvalid do
        another_test_task.update!(slug: @task.slug)
      end

      error_msg = another_test_task.errors.full_messages.to_sentence
      assert_match t("task.slug.immutable"), error_msg
    end

    def test_updating_title_does_not_update_slug
      assert_no_changes -> { @task.reload.slug } do
        updated_task_title = "updated task title"
        @task.update!(title: updated_task_title)
        assert_equal updated_task_title, @task.title
      end
    end

    def test_slug_suffix_is_maximum_slug_count_plus_one_if_two_or_more_slugs_already_exist
      title = "test-task"
      first_task = Task.create!(title: title, assigned_user: @user, task_owner: @user)
      second_task = Task.create!(title: title, assigned_user: @user, task_owner: @user)
      third_task = Task.create!(title: title, assigned_user: @user, task_owner: @user)
      fourth_task = Task.create!(title: title, assigned_user: @user, task_owner: @user)

      assert_equal fourth_task.slug, "#{title.parameterize}-4"

      third_task.destroy

      expected_slug_suffix_for_new_task = fourth_task.slug.split("-").last.to_i + 1

      new_task = Task.create!(title: title, assigned_user: @user, task_owner: @user)
      assert_equal new_task.slug, "#{title.parameterize}-#{expected_slug_suffix_for_new_task}"
    end

    def test_existing_slug_prefixed_in_new_task_title_doesnt_break_slug_generation
      title_having_new_title_as_substring = "buy milk and apple"
      new_title = "buy milk"

      existing_task = Task.create!(title: title_having_new_title_as_substring, assigned_user: @user, task_owner: @user)
      assert_equal title_having_new_title_as_substring.parameterize, existing_task.slug

      new_task = Task.create!(title: new_title, assigned_user: @user, task_owner: @user)
      assert_equal new_title.parameterize, new_task.slug
    end

    def test_having_numbered_slug_substring_in_title_doesnt_affect_slug_generation
      title_with_numbered_substring = "buy 2 apples"

      existing_task = Task.create!(title: title_with_numbered_substring, assigned_user: @user, task_owner: @user)
      assert_equal title_with_numbered_substring.parameterize, existing_task.slug

      substring_of_existing_slug = "buy"
      new_task = Task.create!(title: substring_of_existing_slug, assigned_user: @user, task_owner: @user)

      assert_equal substring_of_existing_slug.parameterize, new_task.slug
    end

    def test_creates_multiple_tasks_with_unique_slug
      tasks = create_list(:task, 10, assigned_user: @user, task_owner: @user)
      slugs = tasks.pluck(:slug)
      assert_equal slugs.uniq, slugs
    end
end
