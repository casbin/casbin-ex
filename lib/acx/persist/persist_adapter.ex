defprotocol Acx.Persist.PersistAdapter do
  def load_policies(adapter)
  def add_policy(adapter, policy)
  def remove_policy(adapter, policy)
  def remove_filtered_policy(adapter, key, idx, attrs)
  def save_policies(adapter, policies)
end
