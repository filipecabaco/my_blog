defmodule Blog.Images.Strategy do
  @moduledoc """
  Behavior for image generation strategies.
  Each strategy implements a specific approach for generating post images.
  """

  @doc """
  Generate an image for a blog post.

  ## Parameters
    - post_content: The full markdown content of the post
    - post_title: The post title/slug (used for naming the output file)

  ## Returns
    - `{:ok, image_url}` - The URL path to the generated image
    - `{:error, reason}` - If generation fails
  """
  @callback generate(post_content :: String.t(), post_title :: String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
end
