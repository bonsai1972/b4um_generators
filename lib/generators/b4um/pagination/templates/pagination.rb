# frozen_string_literal: true

module B4umPagination
  Pagination = Data.define(
    :current_page,
    :per_page,
    :total_count,
    :total_pages,
    :previous_page,
    :next_page
  )

  private

  def b4um_paginate(scope, per_page:)
    current_page = [params.fetch(:page, 1).to_i, 1].max
    total_count = scope.count
    total_pages = [(total_count.to_f / per_page).ceil, 1].max
    current_page = [current_page, total_pages].min

    records = scope
              .limit(per_page)
              .offset((current_page - 1) * per_page)

    pagination = Pagination.new(
      current_page: current_page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      previous_page: current_page > 1 ? current_page - 1 : nil,
      next_page: current_page < total_pages ? current_page + 1 : nil
    )

    [records, pagination]
  end
end
