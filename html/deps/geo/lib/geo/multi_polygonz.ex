defmodule Geo.MultiPolygonZ do
  @moduledoc """
  Defines the MultiPolygonZ struct.
  """

  @type t :: %__MODULE__{
          coordinates: [[[{number, number, number}]]],
          srid: integer | nil,
          properties: map
        }
  defstruct coordinates: [], srid: nil, properties: %{}
end
