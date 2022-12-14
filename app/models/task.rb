# frozen_string_literal: true

class Task < ApplicationRecord
  scope :accessible_to, ->(user_id) { where("task_owner_id = ? OR assigned_user_id = ?", user_id, user_id) }
  enum status: { unstarred: "unstarred", starred: "starred" }

  RESTRICTED_ATTRIBUTES = %i[title task_owner_id assigned_user_id]

  enum progress: { pending: "pending", completed: "completed" }

  has_many :comments, dependent: :destroy
  belongs_to :task_owner, foreign_key: "task_owner_id", class_name: "User"
  belongs_to :assigned_user, foreign_key: "assigned_user_id", class_name: "User"

  # before_validation :assign_title, unless: :title_present

  MAX_TITLE_LENGTH = 125
  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :slug, uniqueness: true
  validate :slug_not_changed
  before_create :set_slug
  after_create :log_task_details

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

    def title_present
      self.title.present?
    end

    def log_task_details
      TaskLoggerJob.perform_later(self)
    end
end
