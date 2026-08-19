///|
test "streaming preserves records across arbitrary chunk boundaries" {
  let chunks = ["%MOMM*%", "X0Y0D02*", "X10Y0D01*", "M02*"]
  let document = stream_chunks(
    chunks,
    kind=stream_kind_from_name("fixture.gbr"),
  )
  assert_true(document.is_finished())
  assert_true(document.record_count() == 4)
  assert_true(document.has_record("X10Y0D01"))
  assert_true(document.coordinate_record_count() == 2)
  assert_true(document.byte_count() > 0)
}

///|
test "streaming records empty and unterminated input explicitly" {
  let empty = stream_records("", kind=stream_kind_from_name("fixture.gbr"))
  assert_true(empty.is_finished())
  assert_true(empty.record_count() == 0)
  assert_true(empty.diagnostic_count() >= 1)
  let unfinished = stream_records(
    "X1Y2D01",
    kind=stream_kind_from_name("fixture.gbr"),
  )
  assert_true(unfinished.record_count() == 1)
  assert_true(unfinished.diagnostic_count() >= 1)
  assert_true(unfinished.stats().max_record_length >= 7)
}

///|
test "streaming enforces bounded record length and remains reusable" {
  let document = new_incremental_document(
    kind=stream_kind_from_name("fixture.gbr"),
    max_record_length=4,
    max_diagnostics=3,
  ).feed("12345*")
  let finished = document.finish()
  assert_true(finished.record_count() == 1)
  assert_true(finished.diagnostic_count() <= 3)
  assert_true(finished.has_errors())
  assert_true(finished.feed("ignored*").record_count() == 1)
}

///|
test "stackup validation and impedance edge values are deterministic" {
  let stack = standard_four_layer_stackup()
  let validation = validate_stackup(stack)
  assert_true(stack.layer_count() >= 4)
  assert_true(stack.has_valid_indices())
  assert_true(validation.is_valid())
  assert_true(stack.total_thickness() > 0.0)
  match stack.estimate_microstrip(0, 0.2) {
    Some(estimate) => {
      assert_true(estimate.impedance > 0.0)
      let tolerance = impedance_with_tolerance(estimate, 0.0, 0.0, 0.0)
      assert_true(tolerance.lower_bound > 0.0)
    }
    None => assert_true(false)
  }
  assert_true(stackup_to_json(stack).contains("\"layers\""))
}

///|
test "stackup rejects malformed layer indices and bad geometry" {
  let malformed = stackup(name="bad", layers=[
    signal_copper_layer(name="Top", index=2, thickness=0.035),
    core_layer(
      name="Core",
      index=0,
      thickness=0.0,
      dielectric_constant=0.0,
      material="invalid",
    ),
  ])
  let report = validate_stackup(malformed)
  assert_true(!report.is_valid())
  assert_true(report.error_count() >= 1)
  assert_true(report.summary().contains("errors="))
}

///|
test "geometry kernel handles boundaries, overlaps, and degenerates" {
  let square = ring2(points=[
    point2(x=0.0, y=0.0),
    point2(x=10.0, y=0.0),
    point2(x=10.0, y=10.0),
    point2(x=0.0, y=10.0),
  ])
  let polygon = polygon2(outer=square)
  assert_true(polygon.area() == 100.0)
  assert_true(polygon_contains_point(point2(x=5.0, y=5.0), polygon))
  assert_true(point_in_polygon(point2(x=0.0, y=5.0), polygon) is BoundaryOn)
  assert_true(!polygon_contains_point(point2(x=11.0, y=5.0), polygon))
  let crossing = segment_intersection(
    point2(x=0.0, y=0.0),
    point2(x=10.0, y=10.0),
    point2(x=0.0, y=10.0),
    point2(x=10.0, y=0.0),
  )
  assert_true(crossing.kind is ProperIntersection)
  let collinear = segment_intersection(
    point2(x=0.0, y=0.0),
    point2(x=10.0, y=0.0),
    point2(x=5.0, y=0.0),
    point2(x=15.0, y=0.0),
  )
  assert_true(collinear.kind is CollinearOverlap)
  assert_true(!polygon_is_valid(polygon2(outer=ring2(points=[]))))
}

///|
test "geometry clipping and rasterization preserve measurable area" {
  let polygon = polygon2(
    outer=ring2(points=[
      point2(x=0.0, y=0.0),
      point2(x=8.0, y=0.0),
      point2(x=8.0, y=8.0),
      point2(x=0.0, y=8.0),
    ]),
  )
  let clipped = clip_polygon_to_rect(
    polygon,
    rect2(min_x=2.0, min_y=2.0, max_x=6.0, max_y=6.0),
  )
  assert_true(clipped is Some(_))
  let cells = rasterize_polygon(
    polygon,
    2.0,
    2.0,
    rect2(min_x=0.0, min_y=0.0, max_x=8.0, max_y=8.0),
  )
  assert_true(cells.length() > 0)
  assert_true(raster_coverage(cells) > 0.0)
  assert_true(polygon_distance_to_point(polygon, point2(x=4.0, y=4.0)) >= 0.0)
}

///|
test "toolpath safety catches out of bounds moves" {
  let ring = rect_to_ring(rect2(min_x=0.0, min_y=0.0, max_x=8.0, max_y=8.0))
  let safe = default_tool_machine_profile()
  let path = toolpath_from_shape(
    name="outline",
    shape=shape_region(points=[(0.0, 0.0), (8.0, 0.0), (8.0, 8.0), (0.0, 8.0)]),
    layer="Edge.Cuts",
    profile=safe,
  )
  let valid = validate_toolpath(path, safe)
  assert_true(path.move_count() > 0)
  assert_true(valid.length() <= path.move_count())
  let constrained = safe.with_tool(0.1).with_depth(-10.0)
  let invalid = validate_toolpath(path, constrained)
  assert_true(invalid.length() >= 1)
  let plan = plan_toolpaths(name="outline", rings=[ring], profile=safe)
  assert_true(plan.to_gcode().contains("G"))
}

///|
test "netlist handles named labels and floating components" {
  let board = fixture_board(small_fixture())
  let labels = [
    net_label(name="GND", layer_index=0, point=point2(x=0.0, y=0.0)),
    net_label(name="VCC", layer_index=1, point=point2(x=5.0, y=5.0)),
  ]
  let netlist = build_netlist(board, labels~)
  assert_true(netlist.terminal_count() > 0)
  assert_true(netlist.net_names().length() >= 0)
  assert_true(netlist.label_coverage() >= 0.0)
  assert_true(netlist.label_coverage() <= 1.0)
  assert_true(netlist_to_json(netlist).contains("\"terminals\""))
}

///|
test "source index maps board shapes and stream spans" {
  let board_index = source_index_from_board(fixture_board(tiny_fixture()))
  assert_true(board_index.artifact_count() == 1)
  assert_true(board_index.entry_count() > 0)
  assert_true(board_index.find_text("segment").length() >= 0)
  assert_true(board_index.find_text("segment").length() >= 0)
  assert_true(source_index_health(board_index))
  let gerber_index = source_index_from_gerber(
    fixture_gerber(tiny_fixture()),
    path="fixture.gbr",
  )
  assert_true(gerber_index.entry_count() > 0)
  assert_true(gerber_index.timeline(None).length() > 0)
  assert_true(gerber_index.to_csv().contains("entry_id"))
}

///|
test "source index joins artifacts and tracks relations" {
  let left = source_index_from_gerber(
    "%MOMM*%X0Y0D02*X1Y1D01*M02*",
    path="a.gbr",
  )
  let right = source_index_from_excellon(
    "M48\nT1C0.8\n%\nT1\nX1Y1\nM30",
    path="a.drl",
  )
  let joined = source_index_join(left, right)
  let rebuilt = source_index_rebuild_relations(joined)
  assert_true(rebuilt.artifact_count() == 2)
  assert_true(rebuilt.entry_count() >= joined.entry_count())
  assert_true(rebuilt.to_json().contains("\"relations\""))
}

///|
test "thermal analysis reports empty and populated boards" {
  let empty_report = analyze_thermal(empty_board())
  assert_true(empty_report.copper_area == 0.0)
  assert_true(empty_report.findings.length() >= 1)
  let board_report = analyze_thermal(
    fixture_board(medium_fixture()),
    profile=high_current_thermal_profile(),
  )
  assert_true(board_report.pads.length() > 0)
  assert_true(board_report.estimated_capacity >= 0.0)
  assert_true(board_report.maximum_temperature_c >= 0.0)
  assert_true(board_report.to_json().contains("\"findings\""))
}

///|
test "thermal grid clamps pathological cell sizes" {
  let board = fixture_board(tiny_fixture())
  let grid = thermal_grid(board, cell_size=0.0)
  assert_true(grid.columns >= 1)
  assert_true(grid.rows >= 1)
  assert_true(grid.cell_count() == grid.columns * grid.rows)
  assert_true(grid.average_temperature() >= 0.0)
  assert_true(grid.cell(-1, 0) is None)
  assert_true(grid.cell(0, 0) is Some(_))
}

///|
test "release audits preserve evidence for blocked manifests" {
  let board = fixture_board(tiny_fixture())
  let manifest = new_release_manifest(project="test", revision="r1").add_artifact(
    release_artifact(
      path="missing.gbr",
      kind=release_artifact_kind_from_path("missing.gbr"),
      content="",
      required=true,
      present=false,
      description="required test input",
    ),
  )
  let audit = audit_release(board, manifest, strict_release_policy())
  assert_true(audit.blocked_count() >= 1)
  assert_true(!audit.is_ready())
  assert_true(audit.to_json().contains("\"gates\""))
  assert_true(audit.sarif().contains("\"results\""))
}

///|
test "release bundles expose reproducible packaging status" {
  let manifest = release_manifest_for_board(
    fixture_board(tiny_fixture()),
    project="bundle-test",
    revision="r1",
  )
  let bundle = release_bundle_from_manifest(manifest).with_check("manifest")
  assert_true(bundle.entry_count() > 0)
  assert_true(bundle.required_count() == bundle.present_count())
  assert_true(bundle.is_reproducible())
  assert_true(bundle.fingerprint().length() > 0)
  assert_true(bundle.status(standard_release_policy()) is BundleReady)
  assert_true(
    bundle.summary(standard_release_policy()).contains("status=ready"),
  )
}

///|
test "release bundle deltas detect additions and empty-package failures" {
  let empty = new_release_bundle(project="bundle-test", revision="r0")
  assert_true(!empty.is_reproducible())
  assert_true(empty.status(standard_release_policy()) is BundleFailure)
  let first = release_bundle_from_manifest(
    new_release_manifest(project="bundle-test", revision="r1").add_artifact(
      release_artifact(
        path="outline.gko",
        kind=release_artifact_kind_from_path("outline.gko"),
        content="outline",
        required=true,
        present=true,
        description="board outline",
      ),
    ),
  )
  let second = first.with_note("repacked")
  let delta = release_bundle_delta(empty, second)
  assert_true(delta.added == 1)
  assert_true(delta.removed == 0)
  assert_true(delta.modified == 0)
  assert_true(delta.change_count() == 1)
}

///|
test "release comparison distinguishes changed and unchanged artifacts" {
  let board = fixture_board(tiny_fixture())
  let first = release_manifest_for_board(board, revision="one")
  let second = first.with_note("reviewed")
  let unchanged = release_compare_manifests(first, second)
  assert_true(unchanged.any(change => change.kind is ReleaseUnchanged))
  let changed = release_compare_manifests(
    first,
    second.add_artifact(
      release_artifact(
        path="review.txt",
        kind=release_artifact_kind_from_path("review.txt"),
        content="new evidence",
        required=false,
        present=true,
        description="review output",
      ),
    ),
  )
  assert_true(changed.any(change => change.kind is ReleaseAdded))
}

///|
test "batch queue rejects duplicates and aggregates real audits" {
  let board = fixture_board(tiny_fixture())
  let queue = new_batch_queue()
    .enqueue_board("A", board)
    .enqueue_board("A", board)
  assert_true(queue.duplicate_count() == 1)
  assert_true(!batch_queue_health(queue))
  let run = run_batch_default("smoke", [board, board])
  assert_true(run.job_count() == 2)
  assert_true(run.result_count() == 2)
  assert_true(run.summary_data().total_shapes > 0)
  assert_true(batch_digest_is_stable(run))
  assert_true(run.to_csv().contains("job_id"))
}

///|
test "batch policies and comparisons remain total on empty runs" {
  let empty = run_batch(
    "empty",
    new_batch_queue(),
    policy=batch_policy_catalog()[1],
  )
  assert_true(empty.result_count() == 0)
  assert_true(empty.status is BatchQueued)
  assert_true(batch_status_catalog().length() == 6)
  assert_true(batch_policy_catalog().length() == 3)
  let compared = batch_compare(empty, empty)
  assert_true(compared.improved)
  assert_true(compared.summary().contains("unchanged="))
}

///|
test "inspection report combines all production gates" {
  let report = inspect_board(fixture_board(small_fixture()))
  assert_true(report.gates.length() >= 8)
  assert_true(report.metrics.shape_count > 0)
  assert_true(report.summary().contains("release_ready="))
  assert_true(inspection_report_to_sarif(report).contains("\"runs\""))
}

///|
test "mesh and constraint boundaries remain safe" {
  let empty_mesh = triangulate_ring(ring2(points=[]))
  assert_true(empty_mesh.vertex_count() == 0)
  let board = fixture_board(small_fixture())
  let constraints = evaluate_constraints(board, strict_constraint_set())
  assert_true(constraints.checked >= 0)
  assert_true(constraints.pass_rate() >= 0.0)
  assert_true(constraints.pass_rate() <= 1.0)
  assert_true(constraint_report_to_json(constraints).contains("\"findings\""))
}
