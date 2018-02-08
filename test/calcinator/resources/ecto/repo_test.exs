defmodule Calcinator.Resources.Ecto.RepoTest do
  alias Alembic.{Document, Error, Pagination, Source}
  alias Alembic.Pagination.Page
  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestComments}
  alias Calcinator.Resources.Ecto.Repo.Repo

  # `Application.(get|put)_env(:calcinator, Calcinator.Resource.Ecto.Repo)` must be synchronous
  use ExUnit.Case, async: false

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    :ok
  end

  describe "list/2" do
    test "valid filter filters the list" do
      [first_author, second_author, third_author] = Factory.insert_list(3, :test_author)

      assert {:ok, list_authors, nil} =
               TestAuthors.list(%{
                 filters: %{
                   "id" => "#{first_author.id},#{third_author.id}"
                 }
               })

      assert length(list_authors) == 2

      list_author_ids = Enum.map(list_authors, & &1.id)

      assert first_author.id in list_author_ids
      refute second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "filtered queries pass through distinct/2 before returning results" do
      insert! = fn ->
        author = Factory.insert(:test_author)

        # Needs to be > 1 matching posts per body to check distinct is happening
        Factory.insert_list(2, :test_post, author: author, body: "Shared Body")

        author
      end

      [first_author, second_author, third_author] =
        insert!
        |> Stream.repeatedly()
        |> Enum.take(3)

      assert {:ok, list_authors, nil} =
               TestAuthors.list(%{
                 filters: %{
                   "id" => "#{first_author.id},#{third_author.id}",
                   "posts.body" => "Shared"
                 }
               })

      assert length(list_authors) == 2

      list_author_ids = Enum.map(list_authors, & &1.id)

      assert first_author.id in list_author_ids
      refute second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "multiple invalid filters return error for each invalid filter" do
      assert {:error, %Document{errors: errors}} =
               TestAuthors.list(%{
                 filters: %{
                   "first_invalid_filter" => "true",
                   "id" => "1,2",
                   "second_invalid_filter" => "false"
                 }
               })

      assert length(errors) == 2

      assert %Error{
               detail: "Unknown second_invalid_filter filter",
               source: %Source{
                 pointer: "/filter/second_invalid_filter"
               },
               status: "422",
               title: "Unknown Filter"
             } in errors

      assert %Error{
               detail: "Unknown first_invalid_filter filter",
               source: %Source{
                 pointer: "/filter/first_invalid_filter"
               },
               status: "422",
               title: "Unknown Filter"
             } in errors
    end

    test "with no filter/3 callback, returns error(s)" do
      assert {:error, %Document{errors: errors}} =
               TestComments.list(%{
                 filters: %{
                   "spam" => "true",
                   "text" => "spam"
                 }
               })

      assert length(errors) == 2
    end
  end

  # Test should be the same as default paginator (`Calcinator.Resources.Ecto.Repo.Pagination.Allow`)
  describe "list/2 without :paginator" do
    setup :without_pagination

    test "without page returns nil pagination" do
      count = 3
      [first_author, second_author, third_author] = Factory.insert_list(count, :test_author)

      assert {:ok, list_authors, nil} = TestAuthors.list(%{})

      assert length(list_authors) == count

      list_author_ids = Enum.map(list_authors, & &1.id)

      assert first_author.id in list_author_ids
      assert second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "with page with one record paginates results" do
      [first_author] = Factory.insert_list(1, :test_author)

      assert {:ok, first_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 1, size: 1},
                # No next or previous for single page
                next: nil,
                previous: nil,
                total_size: 1
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   number: 1,
                   size: 1
                 }
               })

      assert is_list(first_page_authors)
      assert length(first_page_authors)

      first_page_author_ids = Enum.map(first_page_authors, & &1.id)

      assert first_author.id in first_page_author_ids

      assert {:ok, [],
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 1, size: 1},
                next: nil,
                # previous page points to the last page with actual results
                previous: %Page{number: 1, size: 1},
                total_size: 1
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # beyond end
                   number: 2,
                   size: 1
                 }
               })
    end

    test "with page with multiple records paginates results" do
      [first_author, second_author, third_author] = Factory.insert_list(3, :test_author)

      assert {:ok, first_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # No previous on first page
                next: %Page{number: 2, size: 1},
                previous: nil,
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # first page
                   number: 1,
                   size: 1
                 }
               })

      assert is_list(first_page_authors)
      assert length(first_page_authors)

      first_page_author_ids = Enum.map(first_page_authors, & &1.id)

      assert first_author.id in first_page_author_ids

      assert {:ok, second_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # Both next and previous on any middle page
                next: %Page{number: 3, size: 1},
                previous: %Page{number: 1, size: 1},
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # middle page
                   number: 2,
                   size: 1
                 }
               })

      assert is_list(second_page_authors)
      assert length(second_page_authors)

      second_page_author_ids = Enum.map(second_page_authors, & &1.id)

      assert second_author.id in second_page_author_ids

      assert {:ok, third_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # No next on last page
                next: nil,
                previous: %Page{number: 2, size: 1},
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # last page
                   number: 3,
                   size: 1
                 }
               })

      assert is_list(third_page_authors)
      assert length(third_page_authors)

      third_page_author_ids = Enum.map(third_page_authors, & &1.id)

      assert third_author.id in third_page_author_ids
    end
  end

  describe "list/2 with Calcinator.Resources.Ecto.Repo.Pagination.Disallow" do
    setup :disallow_pagination

    test "without page returns all records and nil pagination" do
      count = 3
      [first_author, second_author, third_author] = Factory.insert_list(count, :test_author)

      assert {:ok, list_authors, nil} = TestAuthors.list(%{})

      assert length(list_authors) == count

      list_author_ids = Enum.map(list_authors, & &1.id)

      assert first_author.id in list_author_ids
      assert second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "with page returns error" do
      Factory.insert_list(3, :test_author)

      assert {:error, %Document{errors: errors}} =
               TestAuthors.list(%{page: %{number: 2, size: 1}})

      assert is_list(errors)
      assert length(errors) == 1

      assert %Alembic.Error{
               detail: "Pagination parameters were passed, but they are not allowed",
               source: %Source{pointer: "/page"},
               status: "422",
               title: "Pagination disallowed"
             } in errors
    end
  end

  describe "list/2 with Calcinator.Resources.Ecto.Repo.Pagination.Ignore" do
    setup :ignore_pagination

    test "without page returns all records and nil pagination" do
      count = 3
      [first_author, second_author, third_author] = Factory.insert_list(count, :test_author)

      assert {:ok, list_authors, nil} = TestAuthors.list(%{})

      assert length(list_authors) == count

      list_author_ids = Enum.map(list_authors, & &1.id)

      assert first_author.id in list_author_ids
      assert second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "with page returns all records and nil pagination" do
      count = 3
      [first_author, second_author, third_author] = Factory.insert_list(count, :test_author)

      assert {:ok, list_authors, nil} =
               TestAuthors.list(%{page: %Calcinator.Resources.Page{number: 2, size: 1}})

      assert length(list_authors) == count

      list_author_ids = Enum.map(list_authors, & &1.id)

      assert first_author.id in list_author_ids
      assert second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end
  end

  describe "list/2 with Calcinator.Resources.Ecto.Repo.Pagination.Allow" do
    setup :allow_pagination

    test "without page returns nil pagination" do
      count = 3
      [first_author, second_author, third_author] = Factory.insert_list(count, :test_author)

      assert {:ok, list_authors, nil} = TestAuthors.list(%{})

      assert length(list_authors) == count

      list_author_ids = Enum.map(list_authors, & &1.id)

      assert first_author.id in list_author_ids
      assert second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "with page with one record paginates results" do
      [first_author] = Factory.insert_list(1, :test_author)

      assert {:ok, first_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 1, size: 1},
                # No next or previous for single page
                next: nil,
                previous: nil,
                total_size: 1
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   number: 1,
                   size: 1
                 }
               })

      assert is_list(first_page_authors)
      assert length(first_page_authors)

      first_page_author_ids = Enum.map(first_page_authors, & &1.id)

      assert first_author.id in first_page_author_ids

      assert {:ok, [],
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 1, size: 1},
                next: nil,
                # previous page points to the last page with actual results
                previous: %Page{number: 1, size: 1},
                total_size: 1
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # beyond end
                   number: 2,
                   size: 1
                 }
               })
    end

    test "with page with multiple records paginates results" do
      [first_author, second_author, third_author] = Factory.insert_list(3, :test_author)

      assert {:ok, first_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # No previous on first page
                next: %Page{number: 2, size: 1},
                previous: nil,
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # first page
                   number: 1,
                   size: 1
                 }
               })

      assert is_list(first_page_authors)
      assert length(first_page_authors)

      first_page_author_ids = Enum.map(first_page_authors, & &1.id)

      assert first_author.id in first_page_author_ids

      assert {:ok, second_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # Both next and previous on any middle page
                next: %Page{number: 3, size: 1},
                previous: %Page{number: 1, size: 1},
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # middle page
                   number: 2,
                   size: 1
                 }
               })

      assert is_list(second_page_authors)
      assert length(second_page_authors)

      second_page_author_ids = Enum.map(second_page_authors, & &1.id)

      assert second_author.id in second_page_author_ids

      assert {:ok, third_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # No next on last page
                next: nil,
                previous: %Page{number: 2, size: 1},
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # last page
                   number: 3,
                   size: 1
                 }
               })

      assert is_list(third_page_authors)
      assert length(third_page_authors)

      third_page_author_ids = Enum.map(third_page_authors, & &1.id)

      assert third_author.id in third_page_author_ids
    end
  end

  describe "list/2 with Calcinator.Resources.Ecto.Repo.Pagination.Require" do
    setup :require_pagination

    test "without page returns error" do
      Factory.insert_list(3, :test_author)

      assert {:error, %Document{errors: errors}} = TestAuthors.list(%{})

      assert is_list(errors)
      assert length(errors) == 1

      assert %Error{
               detail: "Pagination parameters were not passed, but they are required",
               source: %Alembic.Source{pointer: "/"},
               status: "422",
               title: "Pagination required"
             } in errors
    end

    test "with page with one record paginates results" do
      [first_author] = Factory.insert_list(1, :test_author)

      assert {:ok, first_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 1, size: 1},
                # No next or previous for single page
                next: nil,
                previous: nil,
                total_size: 1
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   number: 1,
                   size: 1
                 }
               })

      assert is_list(first_page_authors)
      assert length(first_page_authors)

      first_page_author_ids = Enum.map(first_page_authors, & &1.id)

      assert first_author.id in first_page_author_ids

      assert {:ok, [],
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 1, size: 1},
                next: nil,
                # previous page points to the last page with actual results
                previous: %Page{number: 1, size: 1},
                total_size: 1
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # beyond end
                   number: 2,
                   size: 1
                 }
               })
    end

    test "with page with multiple records paginates results" do
      [first_author, second_author, third_author] = Factory.insert_list(3, :test_author)

      assert {:ok, first_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # No previous on first page
                next: %Page{number: 2, size: 1},
                previous: nil,
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # first page
                   number: 1,
                   size: 1
                 }
               })

      assert is_list(first_page_authors)
      assert length(first_page_authors)

      first_page_author_ids = Enum.map(first_page_authors, & &1.id)

      assert first_author.id in first_page_author_ids

      assert {:ok, second_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # Both next and previous on any middle page
                next: %Page{number: 3, size: 1},
                previous: %Page{number: 1, size: 1},
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # middle page
                   number: 2,
                   size: 1
                 }
               })

      assert is_list(second_page_authors)
      assert length(second_page_authors)

      second_page_author_ids = Enum.map(second_page_authors, & &1.id)

      assert second_author.id in second_page_author_ids

      assert {:ok, third_page_authors,
              %Pagination{
                first: %Page{number: 1, size: 1},
                last: %Page{number: 3, size: 1},
                # No next on last page
                next: nil,
                previous: %Page{number: 2, size: 1},
                total_size: 3
              }} =
               TestAuthors.list(%{
                 page: %Calcinator.Resources.Page{
                   # last page
                   number: 3,
                   size: 1
                 }
               })

      assert is_list(third_page_authors)
      assert length(third_page_authors)

      third_page_author_ids = Enum.map(third_page_authors, & &1.id)

      assert third_author.id in third_page_author_ids
    end
  end

  # Functions

  ## Private Functions

  defp allow_pagination(_) do
    swap_paginator(Calcinator.Resources.Ecto.Repo.Pagination.Allow)

    :ok
  end

  defp disallow_pagination(_) do
    swap_paginator(Calcinator.Resources.Ecto.Repo.Pagination.Disallow)

    :ok
  end

  defp ignore_pagination(_) do
    swap_paginator(Calcinator.Resources.Ecto.Repo.Pagination.Ignore)

    :ok
  end

  defp require_pagination(_) do
    swap_paginator(Calcinator.Resources.Ecto.Repo.Pagination.Require)

    :ok
  end

  defp swap_env(transformer) do
    before = Application.get_env(:calcinator, Calcinator.Resources.Ecto.Repo)

    Application.put_env(:calcinator, Calcinator.Resources.Ecto.Repo, transformer.(before))

    on_exit(fn ->
      case before do
        nil -> Application.delete_env(:calcinator, Calcinator.Resources.Ecto.Repo)
        _ -> Application.put_env(:calcinator, Calcinator.Resources.Ecto.Repo, before)
      end
    end)
  end

  def swap_paginator(paginator) do
    swap_env(fn before ->
      put_in((before || [])[:paginator], paginator)
    end)
  end

  defp without_pagination(_) do
    swap_env(fn before ->
      case before do
        nil -> nil
        list when is_list(list) -> Keyword.delete(list, :paginator)
      end
    end)
  end
end
