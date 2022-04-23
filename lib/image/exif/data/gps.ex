defmodule Image.Exif.Gps do
  @moduledoc false
  # Internal representation of GPS tag in the EXIF.

  @type t :: %__MODULE__{
          gps_version_id: any(),
          gps_latitude_ref: any(),
          gps_latitude: any(),
          gps_longitude_ref: any(),
          gps_longitude: any(),
          gps_altitude_ref: any(),
          gps_altitude: any(),
          gps_time_stamp: any(),
          gps_satellites: any(),
          gps_status: any(),
          gps_measure_mode: any(),
          gps_dop: any(),
          gps_speed_ref: any(),
          gps_speed: any(),
          gps_track_ref: any(),
          gps_track: any(),
          gps_img_direction_ref: any(),
          gps_img_direction: any(),
          gps_map_datum: any(),
          gps_dest_latitude_ref: any(),
          gps_dest_latitude: any(),
          gps_dest_longitude_ref: any(),
          gps_dest_longitude: any(),
          gps_dest_bearing_ref: any(),
          gps_dest_bearing: any(),
          gps_dest_distance_ref: any(),
          gps_dest_distance: any(),
          gps_processing_method: any(),
          gps_area_information: any(),
          gps_date_stamp: any(),
          gps_differential: any(),
          gps_h_positioning_error: any()
        }

  @fields [
    :gps_version_id,
    :gps_latitude_ref,
    :gps_latitude,
    :gps_longitude_ref,
    :gps_longitude,
    :gps_altitude_ref,
    :gps_altitude,
    :gps_time_stamp,
    :gps_satellites,
    :gps_status,
    :gps_measure_mode,
    :gps_dop,
    :gps_speed_ref,
    :gps_speed,
    :gps_track_ref,
    :gps_track,
    :gps_img_direction_ref,
    :gps_img_direction,
    :gps_map_datum,
    :gps_dest_latitude_ref,
    :gps_dest_latitude,
    :gps_dest_longitude_ref,
    :gps_dest_longitude,
    :gps_dest_bearing_ref,
    :gps_dest_bearing,
    :gps_dest_distance_ref,
    :gps_dest_distance,
    :gps_processing_method,
    :gps_area_information,
    :gps_date_stamp,
    :gps_differential,
    :gps_h_positioning_error
  ]

  @spec fields :: [atom()]
  @doc false
  def fields, do: @fields

  defstruct @fields

  @spec inspect(data :: t()) :: String.t()
  @doc """
  Returns the human-readable representation of GPS data, e. g. "41°23´16˝N,2°11´50˝E".
  """
  def inspect(%__MODULE__{gps_latitude: nil} = _data), do: ""
  def inspect(%__MODULE__{gps_longitude: nil} = _data), do: ""

  def inspect(%__MODULE__{} = data) do
    # gps_latitude: [41, 23, 16.019], gps_latitude_ref: "N",
    # gps_longitude: [2, 11, 49.584], gps_longitude_ref: "E"
    # 41 deg 23' 16.02" N, 2 deg 11' 49.58" E
    [lat_d, lat_m, lat_s] = data.gps_latitude
    [lon_d, lon_m, lon_s] = data.gps_longitude

    [
      ~s|#{lat_d}°#{lat_m}´#{round(lat_s)}˝#{data.gps_latitude_ref || "N"}|,
      ~s|#{lon_d}°#{lon_m}´#{round(lon_s)}˝#{data.gps_longitude_ref || "N"}|
    ]
    |> Enum.join(",")
  end

  defimpl String.Chars, for: Image.Exif.Gps do
    @moduledoc false
    alias Image.Exif.Gps

    @spec to_string(Gps.t()) :: String.t()
    def to_string(data), do: Gps.inspect(data)
  end
end
