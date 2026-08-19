///|
/// Release bundle planning for reproducible manufacturing handoff.
///
/// A manifest describes the intended release. A bundle is the normalized,
/// reviewable view used by packaging, archival, and CI gates. Keeping this
/// model separate makes it possible to compare revisions without depending
/// on filesystem ordering or a particular archive implementation.
pub enum ReleaseBundleStatus {
  BundleReady
  BundleWarning
  BundleFailure
} derive(Debug, Eq)

///|
pub struct ReleaseBundleEntry {
  path : String
  kind : ReleaseArtifactKind
  digest : String
  bytes : Int
  required : Bool
  present : Bool
  sequence : Int
} derive(Debug)

///|
pub struct ReleaseBundle {
  project : String
  revision : String
  entries : Array[ReleaseBundleEntry]
  checks : Array[String]
  notes : Array[String]
} derive(Debug)

///|
pub struct ReleaseBundleDelta {
  added : Int
  removed : Int
  modified : Int
  unchanged : Int
  previous_fingerprint : String
  current_fingerprint : String
} derive(Debug)

///|
pub fn release_bundle_entry(
  artifact : ReleaseArtifact,
  sequence : Int,
) -> ReleaseBundleEntry {
  {
    path: artifact.path,
    kind: artifact.kind,
    digest: artifact.digest,
    bytes: artifact.bytes,
    required: artifact.required,
    present: artifact.present,
    sequence,
  }
}

///|
pub fn release_bundle_from_manifest(
  manifest : ReleaseManifest,
) -> ReleaseBundle {
  let entries : Array[ReleaseBundleEntry] = []
  for index in 0..<manifest.artifacts.length() {
    entries.push(release_bundle_entry(manifest.artifacts[index], index))
  }
  {
    project: manifest.project,
    revision: manifest.revision,
    entries,
    checks: manifest.declared_checks.copy(),
    notes: manifest.notes.copy(),
  }
}

///|
pub fn new_release_bundle(
  project~ : String,
  revision~ : String,
) -> ReleaseBundle {
  { project, revision, entries: [], checks: [], notes: [] }
}

///|
pub fn ReleaseBundle::entry_count(self : ReleaseBundle) -> Int {
  self.entries.length()
}

///|
pub fn ReleaseBundle::required_count(self : ReleaseBundle) -> Int {
  self.entries.filter(entry => entry.required).length()
}

///|
pub fn ReleaseBundle::present_count(self : ReleaseBundle) -> Int {
  self.entries.filter(entry => entry.present).length()
}

///|
pub fn ReleaseBundle::missing_count(self : ReleaseBundle) -> Int {
  self.entries.filter(entry => entry.required && !entry.present).length()
}

///|
pub fn ReleaseBundle::total_bytes(self : ReleaseBundle) -> Int {
  let mut total = 0
  for entry in self.entries {
    if entry.present {
      total += entry.bytes
    }
  }
  total
}

///|
pub fn ReleaseBundle::has_kind(
  self : ReleaseBundle,
  kind : ReleaseArtifactKind,
) -> Bool {
  self.entries.any(entry => entry.kind == kind)
}

///|
pub fn ReleaseBundle::find(
  self : ReleaseBundle,
  path : String,
) -> ReleaseBundleEntry? {
  for entry in self.entries {
    if entry.path == path {
      return Some(entry)
    }
  }
  None
}

///|
pub fn ReleaseBundle::contains_path(
  self : ReleaseBundle,
  path : String,
) -> Bool {
  self.find(path) is Some(_)
}

///|
pub fn ReleaseBundle::ordered_paths(self : ReleaseBundle) -> Array[String] {
  self.entries.map(entry => entry.path)
}

///|
pub fn ReleaseBundle::with_check(
  self : ReleaseBundle,
  check : String,
) -> ReleaseBundle {
  let checks = self.checks.copy()
  if !checks.contains(check) {
    checks.push(check)
  }
  {
    project: self.project,
    revision: self.revision,
    entries: self.entries,
    checks,
    notes: self.notes,
  }
}

///|
pub fn ReleaseBundle::with_note(
  self : ReleaseBundle,
  note : String,
) -> ReleaseBundle {
  let notes = self.notes.copy()
  notes.push(note)
  {
    project: self.project,
    revision: self.revision,
    entries: self.entries,
    checks: self.checks,
    notes,
  }
}

///|
pub fn ReleaseBundle::has_check(self : ReleaseBundle, check : String) -> Bool {
  self.checks.contains(check)
}

///|
pub fn ReleaseBundle::check_count(self : ReleaseBundle) -> Int {
  self.checks.length()
}

///|
pub fn ReleaseBundle::is_unique(self : ReleaseBundle) -> Bool {
  for left_index in 0..<self.entries.length() {
    for right_index in (left_index + 1)..<self.entries.length() {
      if self.entries[left_index].path == self.entries[right_index].path {
        return false
      }
    }
  }
  true
}

///|
pub fn ReleaseBundle::is_reproducible(self : ReleaseBundle) -> Bool {
  self.entry_count() > 0 &&
  self.is_unique() &&
  self.entries.all(entry => entry.path.length() > 0 && entry.digest.length() > 0)
}

///|
pub fn ReleaseBundle::fingerprint(self : ReleaseBundle) -> String {
  let mut content = self.project + "|" + self.revision
  for entry in self.entries {
    content += "|" + entry.sequence.to_string() + ":" + entry.path
    content += ":" + entry.digest + ":" + entry.bytes.to_string()
  }
  source_hash(content)
}

///|
pub fn ReleaseBundle::status(
  self : ReleaseBundle,
  policy : ReleasePolicy,
) -> ReleaseBundleStatus {
  if !self.is_reproducible() ||
    self.missing_count() > policy.maximum_missing_artifacts {
    BundleFailure
  } else if self.check_count() == 0 || self.present_count() == 0 {
    BundleWarning
  } else {
    BundleReady
  }
}

///|
pub fn release_bundle_status_name(status : ReleaseBundleStatus) -> String {
  match status {
    BundleReady => "ready"
    BundleWarning => "warning"
    BundleFailure => "failure"
  }
}

///|
pub fn ReleaseBundle::summary(
  self : ReleaseBundle,
  policy : ReleasePolicy,
) -> String {
  "project=\{self.project}, revision=\{self.revision}, entries=\{self.entry_count()}, bytes=\{self.total_bytes()}, missing=\{self.missing_count()}, status=\{release_bundle_status_name(self.status(policy))}, fingerprint=\{self.fingerprint()}"
}

///|
pub fn release_bundle_delta(
  previous : ReleaseBundle,
  current : ReleaseBundle,
) -> ReleaseBundleDelta {
  let mut added = 0
  let mut removed = 0
  let mut modified = 0
  let mut unchanged = 0
  for entry in current.entries {
    match previous.find(entry.path) {
      None => added += 1
      Some(old) =>
        if old.digest == entry.digest && old.bytes == entry.bytes {
          unchanged += 1
        } else {
          modified += 1
        }
    }
  }
  for entry in previous.entries {
    if !current.contains_path(entry.path) {
      removed += 1
    }
  }
  {
    added,
    removed,
    modified,
    unchanged,
    previous_fingerprint: previous.fingerprint(),
    current_fingerprint: current.fingerprint(),
  }
}

///|
pub fn ReleaseBundleDelta::change_count(self : ReleaseBundleDelta) -> Int {
  self.added + self.removed + self.modified
}

///|
pub fn ReleaseBundleDelta::is_compatible(
  self : ReleaseBundleDelta,
  policy : ReleasePolicy,
) -> Bool {
  self.removed <= policy.maximum_changes &&
  self.modified + self.added <= policy.maximum_changes
}
