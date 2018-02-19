defmodule CalcinatorTest do
  alias Calcinator.Resources.{TestAuthor, TestPost}

  use ExUnit.Case, async: true

  # Tests

  doctest Calcinator

  describe "Default authorization_module" do
    setup :default_authorization_module

    test "can?(subject, :create, module)", %{
      default_authorization_module: default_authorization_module,
      subject: subject
    } do
      assert default_authorization_module.can?(subject, :create, TestAuthor)
    end

    test "can?(subject, :create, Ecto.Changeset.t)", %{
      default_authorization_module: default_authorization_module,
      subject: subject
    } do
      changeset =
        TestAuthor.changeset(%TestAuthor{}, %{name: "Alice", password: "password", password_confirmation: "password"})

      assert default_authorization_module.can?(subject, :create, changeset)
    end

    test "can?(subject, :delete, struct)", %{
      default_authorization_module: default_authorization_module,
      subject: subject
    } do
      assert default_authorization_module.can?(subject, :delete, %TestAuthor{id: 1})
    end

    test "can?(subject, :index, module)", %{
      default_authorization_module: default_authorization_module,
      subject: subject
    } do
      assert default_authorization_module.can?(subject, :index, TestAuthor)
    end

    test "can?(subject, :show, struct)", %{default_authorization_module: default_authorization_module, subject: subject} do
      assert default_authorization_module.can?(subject, :show, %TestAuthor{})
    end

    test "can?(subject, :show, association_ascent)", %{
      default_authorization_module: default_authorization_module,
      subject: subject
    } do
      post = %TestPost{id: 2}
      author = %TestAuthor{id: 1, posts: [post]}

      assert default_authorization_module.can?(subject, :show, [post, author])
    end

    test "can?(subject, :update, struct)", %{
      default_authorization_module: default_authorization_module,
      subject: subject
    } do
      assert default_authorization_module.can?(subject, :update, %TestAuthor{})
    end
  end

  # Functions

  defp default_authorization_module(_) do
    {:ok, %{default_authorization_module: Calcinator.__struct__().authorization_module, subject: nil}}
  end
end
