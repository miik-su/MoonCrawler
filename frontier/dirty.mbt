///|
pub fn Frontier::drain_changes(self : Frontier) -> Array[@core.Task] {
  let changes = self.dirty.values().to_array()
  self.dirty.clear()
  changes
}
