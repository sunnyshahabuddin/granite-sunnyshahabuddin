# frozen_string_literal: true

class TasksController < ApplicationController
  def index
    tasks = Task.all
    render status: :ok, json: { tasks: tasks }
  end

  def show
    @task = Task.find_by(identifier_name: params[:identifier_name])
  end

  def create
    task = Task.new(task_params)
    task.save!
    respond_with_success(t("successfully_created"))
  end

  private

    def task_params
      params.require(:task).permit(:title)
    end
end
