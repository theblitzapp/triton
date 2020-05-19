defmodule Triton.CQL.Select do
  def build(query) do
    schema = query[:__schema__].__fields__

    select(query[:select], query[:count], query[:__table__], schema) <>
    where(query[:where], query[:prepared]) <>
    order_by(query[:order_by] && List.first(query[:order_by])) <>
    limit(query[:limit]) <>
    allow_filtering(query[:allow_filtering])
  end

  defp select(_, count, table, _) when count === true, do: "SELECT COUNT(*) FROM #{table}"
  defp select(fields, _, table, schema) when is_list(fields) do
    schema_fields = schema |> Enum.map(fn {k, _} -> "#{k}" end)
    query_fields =
      fields
      |> Enum.reduce(
        [],
        fn
          {fun_name, field}, acc ->
            if "#{field}" in schema_fields do
              ["#{fun_name}(#{field})" | acc]
            else
              acc
            end

          k, acc when is_binary(k) -> [k | acc]

          k, acc ->
            if "#{k}" in schema_fields do
              ["#{k}" | acc]
            else
              acc
            end
        end
      )

    "SELECT #{Enum.join(query_fields, ", ")} FROM #{table}"
  end
  defp select(_, _, table, _), do: "SELECT * FROM #{table}"

  defp where(fragments, nil) when is_list(fragments), do: " WHERE " <> (fragments |> Enum.flat_map(fn fragment -> where_fragment(fragment) end) |> Enum.join(" AND "))
  defp where(fragments, prepared) when is_list(fragments) do
    " WHERE " <> (prepared |> Enum.flat_map(fn fragment -> prepared_where_fragment(fragment) end) |> Enum.join(" AND "))
  end

  defp prepared_where_fragment({k, v}) when is_list(v), do: v |> Enum.map(fn {c, v} -> prepared_where_fragment({k, c, v}) end)
  defp prepared_where_fragment({k, _v}), do: ["#{k} = :#{k}"]
  defp prepared_where_fragment({k, :in, _v}), do: "#{k} IN :#{k}"
  defp prepared_where_fragment({k, c, _v}), do: "#{k} #{c} #{k}"

  defp where(_, _), do: ""
  defp where_fragment({k, v}) when is_list(v), do: v |> Enum.map(fn {c, v} -> where_fragment({k, c, v}) end)
  defp where_fragment({k, v}), do: ["#{k} = #{value(v)}"]
  defp where_fragment({k, :in, v}), do: "#{k} IN (#{v |> Enum.map(fn v -> value(v) end) |> Enum.join(", ")})"
  defp where_fragment({k, c, v}), do: "#{k} #{c} #{value(v)}"

  defp order_by({field, direction}), do: " ORDER BY #{field} #{direction}"
  defp order_by(_), do: ""

  defp limit(limit) when is_integer(limit), do: " LIMIT #{limit}"
  defp limit(limit) when is_atom(limit) and not is_nil(limit), do: " LIMIT :#{limit}"
  defp limit(_), do: ""

  defp allow_filtering(true), do: " ALLOW FILTERING"
  defp allow_filtering(_), do: ""

  defp value(v) when is_binary(v), do: "'#{v}'"
  defp value(v) when is_boolean(v), do: "#{v}"
  defp value(v) when is_atom(v), do: ":#{v}"
  defp value(v), do: v
end
