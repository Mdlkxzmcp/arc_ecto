defmodule Arc.Ecto.Changeset do
  @spec cast_attachments(
          Ecto.Schema.t() | Ecto.Changeset.t(),
          :invalid | map(),
          [String.t() | atom()],
          Keyword.t()
        ) :: Ecto.Changeset.t()
  def cast_attachments(changeset_or_data, params, allowed, options \\ []) do
    scope =
      case changeset_or_data do
        %Ecto.Changeset{} -> Ecto.Changeset.apply_changes(changeset_or_data)
        %{__meta__: _} -> changeset_or_data
      end

    # Cast supports both atom and string keys, ensure we're matching on both.
    allowed_param_keys =
      Enum.map(allowed, fn key ->
        case key do
          key when is_binary(key) -> key
          key when is_atom(key) -> Atom.to_string(key)
        end
      end)

    arc_params =
      case params do
        :invalid ->
          :invalid

        %{} ->
          params
          |> Arc.Ecto.Changeset.Helpers.convert_params_to_binary()
          |> Map.take(allowed_param_keys)
          |> Enum.reduce([], fn
            # Don't wrap nil casts in the scope object
            {field, nil}, fields ->
              [{field, nil} | fields]

            # Allow casting Plug.Uploads
            {field, upload = %{__struct__: Plug.Upload}}, fields ->
              [{field, {upload, scope}} | fields]

            # Allow casting binary data structs
            {field, upload = %{filename: filename, binary: binary}}, fields
            when is_binary(filename) and is_binary(binary) ->
              [{field, {upload, scope}} | fields]

            # If casting a binary (path), ensure we've explicitly allowed paths
            {field, path}, fields when is_binary(path) ->
              cond do
                Keyword.get(options, :allow_urls, false) and Regex.match?(~r/^https?:\/\//, path) ->
                  [{field, {path, scope}} | fields]

                Keyword.get(options, :allow_paths, false) ->
                  [{field, {path, scope}} | fields]

                true ->
                  fields
              end
          end)
          |> Enum.into(%{})
      end

    Ecto.Changeset.cast(changeset_or_data, arc_params, allowed)
  end
end
