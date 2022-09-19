defmodule ExtusTest do
  use ExUnit.Case
  doctest Extus

  def callback_func_for_post(file_info, headers) do
    assert Map.get(file_info, :size) == 1919488
    assert Enum.at(headers, 0) == {"upload-length", "1919488"}
    assert Enum.at(headers, 1) == {"upload-metadata",
             "filename L1VzZXJzL3JhamF0Y2hhdWRoYXJ5L3dvcmsvZ2l0aHViL2ZpbGVfdXBsb2FkL3Rlc3QvZmlsZXMvdG1wX3ZpZGVvLm1wNA=="}
    assert Enum.at(headers, 2) == {"user_id", "37ba9201-0f97-4b71-a2d2-829624203445"}
  end

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

  # test for profile-image path in get_upload_location
  test "get_upload_location profile image" do
    identifier = "12333"
    upload_type = "PROFILE_IMAGE"
    conn = %Plug.Conn{
    }
    result = ExTus.Actions.get_upload_location(conn, upload_type, identifier)
    expected_result = "https://www.example.com/profile-image/#{identifier}"
    assert result == expected_result
  end

  # test for video-answer path in get_upload_location
  test "get_upload_location video answer" do
    identifier = "12333"
    upload_type = "VIDEO_ANSWER"
    conn = %Plug.Conn{
    }
    result = ExTus.Actions.get_upload_location(conn, upload_type, identifier)
    expected_result = "https://www.example.com/videos/#{identifier}"
    assert result == expected_result
  end

  # test for files path in get_upload_location
  test "get_upload_location files" do
    identifier = "12333"
    upload_type = ""
    conn = %Plug.Conn{
    }
    result = ExTus.Actions.get_upload_location(conn, upload_type, identifier)
    expected_result = "https://www.example.com/files/#{identifier}"
    assert result == expected_result
  end

  # tests for post function for profile-image path
  test "call post func for profile image" do
    conn = %Plug.Conn{
      req_headers: [
        {"upload-length", "537919488"},
        {"upload-metadata",
          "filename L1VzZXJzL3JhamF0Y2hhdWRoYXJ5L3dvcmsvZ2l0aHViL2ZpbGVfdXBsb2FkL3Rlc3QvZmlsZXMvdG1wX3ZpZGVvLm1wNA=="},
        {"user_id", "37ba9201-0f97-4b71-a2d2-829624203445"}
      ],
      request_path: "/profile-image",
    }
    result = ExTus.Actions.post(conn, &callback_func_for_post/2)
    assert Map.get(result, :request_path) == "/profile-image"
  end

  # tests for post function for files path
  test "call post func for files" do
    conn = %Plug.Conn{
      req_headers: [
        {"upload-length", "1919488"},
        {"upload-metadata",
          "filename L1VzZXJzL3JhamF0Y2hhdWRoYXJ5L3dvcmsvZ2l0aHViL2ZpbGVfdXBsb2FkL3Rlc3QvZmlsZXMvdG1wX3ZpZGVvLm1wNA=="},
        {"user_id", "37ba9201-0f97-4b71-a2d2-829624203445"}
      ],
      request_path: "/files",
    }
    result = ExTus.Actions.post(conn, &callback_func_for_post/2)
    assert Map.get(result, :request_path) == "/files"
  end
end
