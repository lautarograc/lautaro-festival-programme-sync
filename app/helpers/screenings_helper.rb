module ScreeningsHelper
  def screenings_sort_link(label, key, current_sort:, current_direction:)
    active = current_sort == key
    next_direction = active && current_direction != "desc" ? "desc" : "asc"

    query = request.query_parameters.merge("sort" => key, "direction" => next_direction).except("page")
    arrow = active ? (current_direction == "desc" ? " ↓" : " ↑") : ""

    link_to "#{label}#{arrow}", screenings_path(query), class: "hover:text-gray-700"
  end
end
