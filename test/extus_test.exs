defmodule ExtusTest do
  use ExUnit.Case
  doctest Extus

  test "parse_meta_data should ignore if filetype is empty" do
    meta_str = "filename jMTJlOWYwOS5tcDQ=,filetype"
    meta = ExTus.Utils.parse_meta_data(meta_str)
  end

  test "parse_meta_data should parse with filetype" do
    meta_str = "filename jMTJlOWYwOS5tcDQ=,filetype png"
    meta = ExTus.Utils.parse_meta_data(meta_str)
  end

  test "parse_meta_data should parse without filetype" do
    meta_str = "filename jMTJlOWYwOS5tcDQ="
    meta = ExTus.Utils.parse_meta_data(meta_str)
  end
end
