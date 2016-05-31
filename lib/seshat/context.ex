defprotocol Seshat.Context do
  def lookup(context, id, user, prev_state \\ nil)
  def serialize(context)

  def apply_op(context, type, key, op)

  def list_count_keys(context)
  def list_property_keys(context)
  def list_flag_keys(context)
  def list_tag_keys(context)

  def fetch_count(context, key)
  def fetch_property(context, key)
  def fetch_flag(context, key)
  def fetch_tags(context, key)

  def delete(context)

  Kernel.def apply(context, changeset) do
    Seshat.Changeset.apply(changeset, context, fn(context, type, key, op) ->
      apply_op(context, type, key, op)
    end)
  end

  Kernel.def get_count(context, key, default \\ 0) do
    case fetch_count(context, key) do
      :error ->
        default
      {:ok, value} ->
        value
    end
  end

  Kernel.def get_property(context, key, default \\ nil) do
    case fetch_property(context, key) do
      :error ->
        default
      {:ok, value} ->
        value
    end
  end

  Kernel.def get_flag(context, key, default \\ false) do
    case fetch_flag(context, key) do
      :error ->
        default
      {:ok, value} ->
        value
    end
  end

  Kernel.def get_tags(context, key, default \\ []) do
    case fetch_tags(context, key) do
      :error ->
        default
      {:ok, value} ->
        value
    end
  end
end
