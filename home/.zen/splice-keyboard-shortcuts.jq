def modDefaults: { control: false, alt: false, shift: false, meta: false, accel: false };
def entryDefaults: {
  key: "", keycode: null, group: "other", l10nId: null,
  modifiers: modDefaults, action: null,
  disabled: false, reserved: false, internal: false
};
# spell the modifier set out, so an override never inherits stale modifiers
def normalize: if has("modifiers") then .modifiers |= (modDefaults * .) else . end;

($ov[0] | map(normalize)) as $overrides
| ($overrides | map({ key: .id, value: . }) | from_entries) as $byId
| (.shortcuts | map(.id)) as $known
| .shortcuts = (
    # zen keeps id-less entries (alternate bindings); they can never be overridden
    (.shortcuts | map(if .id != null and $byId[.id] then . * $byId[.id] else . end))
    + ($overrides | map(select(.id as $id | $known | index($id) | not)) | map(entryDefaults * .))
  )
