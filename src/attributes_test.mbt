///|
test "attributes parse file function and software" {
  let attributes = GerberAttributes::parse(
    "%TF.FileFunction,Copper,L1,Top*%TF.GenerationSoftware,KiCad*",
  )
  assert_true(attributes.count() == 2)
  assert_true(attributes.file_function() is Some("Copper"))
  assert_true(attributes.generation_software() is Some("KiCad"))
  assert_true(attributes.has("FileFunction"))
  assert_true(attributes.first("FileFunction") is Some("Copper"))
  assert_true(attributes.to_json().contains("GenerationSoftware"))
}

///|
test "attribute scope and round trip are stable" {
  let file = parse_attribute_record("TF.Part,Single")
  let aperture = parse_attribute_record("TA.AperFunction,ComponentPad")
  let object = parse_attribute_record("TO.N,Net-(U1-1)")
  let delete = parse_attribute_record("TD.Part")
  assert_true(file is Some(_))
  assert_true(aperture is Some(_))
  assert_true(object is Some(_))
  assert_true(delete is Some(_))
  assert_true(file.unwrap().scope is FileAttribute)
  assert_true(aperture.unwrap().scope is ApertureAttribute)
  assert_true(object.unwrap().scope is ObjectAttribute)
  assert_true(delete.unwrap().scope is DeleteAttribute)
  assert_true(file.unwrap().to_record().contains("TF"))
}

///|
test "layer roles are inferred from file function" {
  let top = layer_metadata("F.Cu", "%TF.FileFunction,Copper,L1,Top*")
  let bottom = layer_metadata("B.Cu", "%TF.FileFunction,Copper,L2,Bot*")
  let mask = layer_metadata("F.Mask", "%TF.FileFunction, Soldermask,Top*")
  let drill = layer_metadata("PTH.drl", "%TF.FileFunction,Plated,1,2*")
  assert_true(top.role is TopCopperRole)
  assert_true(bottom.role is BottomCopperRole)
  assert_true(mask.role is SolderMaskRole)
  assert_true(drill.kind is Drill || drill.role is UnknownRole)
  assert_true(top.to_json().contains("top-copper"))
}

///|
test "attribute collections merge repeated values" {
  let attributes = new_gerber_attributes()
  attributes.add(
    gerber_attribute(
      scope=file_attribute_scope(),
      name="Comment",
      values=["one"],
      record="TF.Comment,one",
    ),
  )
  attributes.add(
    gerber_attribute(
      scope=file_attribute_scope(),
      name="Comment",
      values=["two", "three"],
      record="TF.Comment,two,three",
    ),
  )
  assert_true(attributes.get("Comment").length() == 3)
  assert_true(attributes.part() is None)
  assert_true(attribute_scope_prefix(object_attribute_scope()) == "TO")
  assert_true(attribute_scope_name(delete_attribute_scope()) == "delete")
}
