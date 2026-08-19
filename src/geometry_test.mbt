///|
test "point vector operations are stable" {
  let a = point2(x=3.0, y=4.0)
  let b = point2(x=1.0, y=2.0)
  assert_true(a.add(b) == point2(x=4.0, y=6.0))
  assert_true(a.sub(b) == point2(x=2.0, y=2.0))
  assert_true(a.scale(0.5) == point2(x=1.5, y=2.0))
  assert_true(a.length() == 5.0)
  assert_true(a.distance(b) > 2.8)
  assert_true(a.lerp(b, 0.5) == point2(x=2.0, y=3.0))
}

///|
test "rectangles normalize and intersect" {
  let outer = rect2(min_x=5.0, min_y=5.0, max_x=0.0, max_y=10.0)
  let inner = rect2(min_x=1.0, min_y=6.0, max_x=3.0, max_y=8.0)
  assert_true(outer.min_x == 0.0)
  assert_true(outer.contains_rect(inner))
  assert_true(outer.intersects(inner))
  assert_true(outer.intersection(inner) is Some(_))
  assert_true(outer.width() == 5.0)
  assert_true(outer.height() == 5.0)
  assert_true(outer.area() == 25.0)
}

///|
test "polyline computes perimeter and signed area" {
  let square = polyline(
    [
      point2(x=0.0, y=0.0),
      point2(x=4.0, y=0.0),
      point2(x=4.0, y=3.0),
      point2(x=0.0, y=3.0),
    ],
    closed=true,
  )
  assert_true(square.length() == 14.0)
  assert_true(square.area() == 12.0)
  assert_true(square.signed_area() > 0.0)
  assert_true(square.bounds() is Some(_))
  assert_true(square.reversed().signed_area() < 0.0)
}

///|
test "polygon contains boundary and rejects outside" {
  let polygon = [
    point2(x=0.0, y=0.0),
    point2(x=10.0, y=0.0),
    point2(x=10.0, y=10.0),
    point2(x=0.0, y=10.0),
  ]
  assert_true(polygon_contains(polygon, point2(x=5.0, y=5.0)))
  assert_true(polygon_contains(polygon, point2(x=0.0, y=5.0)))
  assert_true(!polygon_contains(polygon, point2(x=11.0, y=5.0)))
  assert_true(!polygon_self_intersects(polygon))
}

///|
test "self intersecting polygon is detected" {
  let bow = [
    point2(x=0.0, y=0.0),
    point2(x=4.0, y=4.0),
    point2(x=0.0, y=4.0),
    point2(x=4.0, y=0.0),
  ]
  assert_true(polygon_self_intersects(bow))
  assert_true(segments_intersect(bow[0], bow[1], bow[2], bow[3]))
}

///|
test "arc sampling produces bounded segments" {
  let arc = arc_from_offsets(
    point2(x=0.0, y=0.0),
    point2(x=10.0, y=0.0),
    5.0,
    0.0,
    counter_clockwise_arc_direction(),
  )
  assert_true(arc.bounds().width() > 0.0)
  assert_true(arc.length() > 0.0)
  assert_true(arc.sample(maximum_step=1.0).length() > 2)
  assert_true(arc.to_segments(0.2).length() > 1)
  assert_true(arc.bounds().max_x >= 10.0)
}

///|
test "arc collections aggregate and flatten" {
  let collection = new_arc_collection()
  collection.push(
    arc2(
      center=point2(x=0.0, y=0.0),
      start=point2(x=1.0, y=0.0),
      end=point2(x=0.0, y=1.0),
      direction=counter_clockwise_arc_direction(),
    ),
  )
  assert_true(collection.length() > 1.0)
  assert_true(collection.bounds() is Some(_))
  assert_true(collection.flatten(0.1).length() > 1)
}

///|
test "unit conversion and ranges handle negative values" {
  assert_true(convert(1.0, from=inch_unit(), to=millimeter_unit()) == 25.4)
  let range = double_range(start=-2.0, end=3.0)
  assert_true(range.length() == 5.0)
  assert_true(range.contains(0.0))
  assert_true(range.clamp(-10.0) == -2.0)
  assert_true(approx_equal(1.0, 1.0000001))
}

///|
test "circle bounds contain its center" {
  let circle = circle2(point2(x=2.0, y=3.0), -2.0)
  assert_true(circle.bounds().width() == 4.0)
  assert_true(circle.contains(point2(x=2.0, y=3.0)))
  assert_true(circle.bounds().contains(point2(x=2.0, y=3.0)))
}
