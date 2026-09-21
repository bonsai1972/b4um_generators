# frozen_string_literal: true

module B4umSearch
  private

  def b4um_search(scope, query)
    return scope if query.blank?

    searchable_columns = scope.klass.columns.select do |column|
      %i[string text].include?(column.type)
    end

    return scope if searchable_columns.empty?

    table_name = scope.klass.connection.quote_table_name(
      scope.klass.table_name
    )

    conditions = searchable_columns.map do |column|
      column_name = scope.klass.connection.quote_column_name(
        column.name
      )

      "LOWER(#{table_name}.#{column_name}) LIKE :b4um_query"
    end

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.strip.downcase)}%"

    scope.where(
      conditions.join(" OR "),
      b4um_query: pattern
    )
  end
end
