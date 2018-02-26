defmodule Calcinator.PryIn.InstrumenterTest do
  use Calcinator.PryIn.Case

  require Ecto.Query

  import Calcinator.Resources.Ecto.Repo.Repo.Case
  import Ecto.Query
  import Phoenix.ConnTest
  import Plug.Conn
  import Calcinator.Router.Helpers

  alias Calcinator.Resources.Ecto.Repo.{Factory, Repo, TestAuthors, TestPosts}
  alias Calcinator.Resources.{TestAuthor, TestPost}
  alias Calcinator.Meta.Beam
  alias Calcinator.{Endpoint, TestAuthorView, TestPostView}
  alias PryIn.{CustomTrace, InteractionStore}

  @authorization_module "Calcinator.Authorization.SubjectLess"
  @controller "Calcinator.TestPostController"
  @endpoint Calcinator.Endpoint
  @subject "nil"

  describe "in Calcinator.Controller" do
    setup ~w(setup_conn setup_meta)a

    test "create/3", %{conn: conn, meta: meta} do
      test_author = %TestAuthor{id: author_id} = Factory.insert(:test_author)
      body = "First Post!"
      formatted_author_id = to_string(author_id)

      params = %{
        "meta" => meta,
        "data" => %{
          "type" => "test-posts",
          "attributes" => %{
            "body" => body
          },
          "relationships" => %{
            "author" => %{
              "data" => %{
                "type" => "test-authors",
                "id" => formatted_author_id
              }
            }
          }
        },
        "include" => "author"
      }

      assert %{
               context_by_key_list_by_event: %{
                 "alembic" => alembic_context_by_key_list,
                 "calcinator_authorization" => calcinator_authorization_context_by_key_list,
                 "calcinator_resources" => calcinator_resources_context_by_key_list,
                 "calcinator_view" => calcinator_view_context_by_key_list
               },
               custom_metric_count: custom_metric_count,
               custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
             } =
               request(%{controller: @controller, action: "create"}, fn ->
                 conn = post(conn, test_post_path(conn, :create), params)

                 assert %{
                          "data" => %{
                            "type" => "test-posts",
                            "id" => id,
                            "attributes" => %{
                              "body" => ^body
                            },
                            "relationships" => %{
                              "author" => %{
                                "data" => %{
                                  "type" => "test-authors",
                                  "id" => ^formatted_author_id
                                }
                              }
                            }
                          },
                          "included" => included
                        } = json_response(conn, :created)

                 assert is_binary(id)
                 assert is_list(included)
                 assert length(included) == 1

                 included_by_id_by_type =
                   Enum.reduce(included, %{}, fn resource = %{"type" => type, "id" => id}, acc ->
                     put_in(acc, [Access.key(type, %{}), id], resource)
                   end)

                 test_author_by_id = included_by_id_by_type["test-authors"]

                 assert is_map(test_author_by_id)

                 test_author_name = test_author.name

                 assert %{
                          "attributes" => %{
                            "name" => ^test_author_name
                          }
                        } = test_author_by_id[formatted_author_id]
               end)

      assert %{"action" => ":create", "params" => inspect(params)} in alembic_context_by_key_list

      resources_module = "Calcinator.Resources.Ecto.Repo.TestPosts"
      ecto_schema_module = "Calcinator.Resources.TestPost"
      creatable = "%#{ecto_schema_module}{id: nil}"
      changeset = "%Ecto.Changeset{data: #{creatable}}"

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "insert",
               "changeset" => changeset,
               "query_options" =>
                 inspect(%{
                   associations: [:author],
                   filters: %{},
                   meta: meta,
                   page: nil,
                   sorts: []
                 }),
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{"callback" => "changeset", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      created_id = Repo.one!(from(tp in TestPost, select: tp.id))
      created = "%#{ecto_schema_module}{id: #{created_id}}"

      # can(subject, :create, ecto_schema_module)
      assert %{
               "action" => "create",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => ecto_schema_module
             } in calcinator_authorization_context_by_key_list

      # can(subject, :create, changeset)
      assert %{
               "action" => "create",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => changeset
             } in calcinator_authorization_context_by_key_list

      # authorized(calcinator, created)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => created
             } in calcinator_authorization_context_by_key_list

      assert %{
               "callback" => "show",
               "resource" => created,
               "subject" => @subject,
               "view_module" => "Calcinator.TestPostView"
             } in calcinator_view_context_by_key_list

      assert custom_metric_count == 9

      assert custom_metric_count_by_function_by_module_by_key == %{
               "alembic" => %{
                 "Calcinator" => %{
                   "document/2" => 1
                 }
               },
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 4
                 }
               },
               "calcinator_view" => %{
                 "Calcinator" => %{
                   "view/3" => 1
                 }
               }
             }
    end
  end

  describe "in Calcinator" do
    test "create/2" do
      meta = checkout_meta()

      %TestAuthor{id: author_id} = Factory.insert(:test_author)
      body = "First Post!"

      params = %{
        "meta" => meta,
        "data" => %{
          "type" => "test-posts",
          "attributes" => %{
            "body" => body
          },
          "relationships" => %{
            "author" => %{
              "data" => %{
                "type" => "test-authors",
                "id" => to_string(author_id)
              }
            }
          }
        },
        "include" => "author"
      }

      assert %{
               context_by_key_list_by_event: %{
                 "alembic" => alembic_context_by_key_list,
                 "calcinator_authorization" => calcinator_authorization_context_by_key_list,
                 "calcinator_resources" => calcinator_resources_context_by_key_list,
                 "calcinator_view" => calcinator_view_context_by_key_list
               },
               custom_metric_count: custom_metric_count,
               custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
             } =
               custom_trace(%{group: "TestPost", key: "create"}, fn ->
                 assert {:ok, _} =
                          Calcinator.create(
                            %Calcinator{
                              associations_by_include: %{
                                "author" => :author
                              },
                              ecto_schema_module: TestPost,
                              resources_module: TestPosts,
                              view_module: TestPostView
                            },
                            params
                          )
               end)

      assert %{"action" => ":create", "params" => inspect(params)} in alembic_context_by_key_list

      resources_module = "Calcinator.Resources.Ecto.Repo.TestPosts"
      ecto_schema_module = "Calcinator.Resources.TestPost"
      creatable = "%#{ecto_schema_module}{id: nil}"
      changeset = "%Ecto.Changeset{data: #{creatable}}"

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "insert",
               "changeset" => changeset,
               "query_options" =>
                 inspect(%{
                   associations: [:author],
                   filters: %{},
                   meta: meta,
                   page: nil,
                   sorts: []
                 }),
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{"callback" => "changeset", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      created_id = Repo.one!(from(tp in TestPost, select: tp.id))
      created = "%#{ecto_schema_module}{id: #{created_id}}"

      # can(subject, :create, ecto_schema_module)
      assert %{
               "action" => "create",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => ecto_schema_module
             } in calcinator_authorization_context_by_key_list

      # can(subject, :create, changeset)
      assert %{
               "action" => "create",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => changeset
             } in calcinator_authorization_context_by_key_list

      # authorized(calcinator, created)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => created
             } in calcinator_authorization_context_by_key_list

      assert %{
               "callback" => "show",
               "resource" => created,
               "subject" => @subject,
               "view_module" => "Calcinator.TestPostView"
             } in calcinator_view_context_by_key_list

      assert custom_metric_count == 9

      assert custom_metric_count_by_function_by_module_by_key == %{
               "alembic" => %{
                 "Calcinator" => %{
                   "document/2" => 1
                 }
               },
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 4
                 }
               },
               "calcinator_view" => %{
                 "Calcinator" => %{
                   "view/3" => 1
                 }
               }
             }
    end

    test "delete/2" do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      %{
        context_by_key_list_by_event: %{
          "calcinator_authorization" => calcinator_authorization_context_by_key_list,
          "calcinator_resources" => calcinator_resources_context_by_key_list
        },
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } =
        custom_trace(%{group: "TestAuthor", key: "delete"}, fn ->
          :ok =
            Calcinator.delete(
              %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView},
              %{
                "id" => id,
                "meta" => meta
              }
            )
        end)

      resources_module = "Calcinator.Resources.Ecto.Repo.TestAuthors"
      target = "%Calcinator.Resources.TestAuthor{id: #{id}}"

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "get",
               "id" => to_string(id),
               "query_options" =>
                 inspect(%{
                   associations: [],
                   filters: %{},
                   meta: meta,
                   page: nil,
                   sorts: []
                 }),
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{"callback" => "changeset", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "delete",
               "changeset" => "%Ecto.Changeset{data: #{target}}",
               "query_options" =>
                 inspect(%{
                   associations: [],
                   filters: %{},
                   meta: meta,
                   page: nil,
                   sorts: []
                 }),
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "action" => "delete",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => target
             } in calcinator_authorization_context_by_key_list

      assert custom_metric_count == 6

      assert %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "can/3" => 1
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 5
                 }
               }
             } == custom_metric_count_by_function_by_module_by_key
    end

    test "get_related_resource/3" do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{id: related_id}, id: id} = Factory.insert(:test_post)

      %{
        context_by_key_list_by_event: %{
          "calcinator_authorization" => calcinator_authorization_context_by_key_list,
          "calcinator_resources" => calcinator_resources_context_by_key_list,
          "calcinator_view" => calcinator_view_context_by_key_list
        },
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } =
        custom_trace(%{group: "TestPost", key: "get_related_resource"}, fn ->
          {:ok, _} =
            Calcinator.get_related_resource(
              %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView},
              %{
                "post_id" => id,
                "meta" => meta
              },
              %{
                related: %{
                  view_module: TestAuthorView
                },
                source: %{
                  association: :author,
                  id_key: "post_id"
                }
              }
            )
        end)

      resources_module = "Calcinator.Resources.Ecto.Repo.TestPosts"

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "get",
               "id" => to_string(id),
               "query_options" => "%{associations: [:author]}",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      source = "%Calcinator.Resources.TestPost{id: #{id}}"
      related = "%Calcinator.Resources.TestAuthor{id: #{related_id}}"

      # can(subject, :show, source)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => source
             } in calcinator_authorization_context_by_key_list

      # can(subject, :show, [related, source])
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "[#{related}, #{source}]"
             } in calcinator_authorization_context_by_key_list

      # authorized(calcinator, related)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => related
             } in calcinator_authorization_context_by_key_list

      assert %{
               "callback" => "get_related_resource",
               "related_resource" => related,
               "source_association" => "author",
               "source_resource" => source,
               "subject" => @subject,
               "view_module" => "Calcinator.TestPostView"
             } in calcinator_view_context_by_key_list

      assert custom_metric_count == 7

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 3
                 }
               },
               "calcinator_view" => %{
                 "Calcinator" => %{
                   "view/3" => 1
                 }
               }
             }
    end

    test "index/3" do
      meta = checkout_meta()
      count = 2
      test_authors = Factory.insert_list(count, :test_author)

      assert %{
               context_by_key_list_by_event: %{
                 "calcinator_authorization" => calcinator_authorization_context_by_key_list,
                 "calcinator_resources" => calcinator_resources_context_by_key_list,
                 "calcinator_view" => calcinator_view_context_by_key_list
               },
               custom_metric_count: custom_metric_count,
               custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
             } =
               custom_trace(%{group: "TestAuthor", key: "index"}, fn ->
                 assert {:ok, %{"data" => data}} =
                          Calcinator.index(
                            %Calcinator{
                              ecto_schema_module: TestAuthor,
                              resources_module: TestAuthors,
                              view_module: TestAuthorView
                            },
                            %{
                              "meta" => meta
                            },
                            %{base_uri: %URI{}}
                          )

                 assert length(data) == count
               end)

      ecto_schema_module = "Calcinator.Resources.TestAuthor"

      assert %{
               "action" => "index",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => ecto_schema_module
             } in calcinator_authorization_context_by_key_list

      resources_module = "Calcinator.Resources.Ecto.Repo.TestAuthors"

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "list",
               "query_options" =>
                 inspect(%{
                   associations: [],
                   filters: %{},
                   meta: meta,
                   page: nil,
                   sorts: []
                 }),
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert [
               %{
                 "callback" => "index",
                 "resources" => resources,
                 "subject" => @subject,
                 "view_module" => "Calcinator.TestAuthorView"
               }
             ] = calcinator_view_context_by_key_list

      resource_elements =
        ~r/\[(?<resource_one>.+), (?<resource_two>.+)\]/
        |> Regex.named_captures(resources)
        |> Map.values()

      Enum.each(test_authors, fn test_author ->
        assert "%#{ecto_schema_module}{id: #{test_author.id}}" in resource_elements
      end)

      assert custom_metric_count == 5

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "can/3" => 1
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 3
                 }
               },
               "calcinator_view" => %{
                 "Calcinator" => %{
                   "view/3" => 1
                 }
               }
             }
    end

    test "show/3" do
      meta = checkout_meta()
      test_author = Factory.insert(:test_author)

      %{
        context_by_key_list_by_event: %{
          "calcinator_authorization" => calcinator_authorization_context_by_key_list,
          "calcinator_resources" => calcinator_resources_context_by_key_list,
          "calcinator_view" => calcinator_view_context_by_key_list
        },
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } =
        custom_trace(%{group: "TestAuthor", key: "show"}, fn ->
          {:ok, _} =
            Calcinator.show(
              %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView},
              %{
                "id" => test_author.id,
                "meta" => meta
              }
            )
        end)

      resources_module = "Calcinator.Resources.Ecto.Repo.TestAuthors"
      resource = "%Calcinator.Resources.TestAuthor{id: #{test_author.id}}"

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "get",
               "id" => to_string(test_author.id),
               "query_options" =>
                 inspect(%{
                   associations: [],
                   filters: %{},
                   meta: meta,
                   page: nil,
                   sorts: []
                 }),
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      # can(subject, :show, resource)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => resource
             } in calcinator_authorization_context_by_key_list

      # authorized(calcinator, resource)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => resource
             } in calcinator_authorization_context_by_key_list

      assert %{
               "callback" => "show",
               "resource" => resource,
               "subject" => @subject,
               "view_module" => "Calcinator.TestAuthorView"
             } in calcinator_view_context_by_key_list

      assert custom_metric_count == 6

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 1
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 3
                 }
               },
               "calcinator_view" => %{
                 "Calcinator" => %{
                   "view/3" => 1
                 }
               }
             }
    end

    test "show_relationship/3" do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{id: related_id}, id: id} = Factory.insert(:test_post)

      %{
        context_by_key_list_by_event: %{
          "calcinator_authorization" => calcinator_authorization_context_by_key_list,
          "calcinator_resources" => calcinator_resources_context_by_key_list,
          "calcinator_view" => calcinator_view_context_by_key_list
        },
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } =
        custom_trace(%{group: "TestPost", key: "show_relationship"}, fn ->
          {:ok, _} =
            Calcinator.show_relationship(
              %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView},
              %{
                "post_id" => id,
                "meta" => meta
              },
              %{
                related: %{
                  view_module: TestAuthorView
                },
                source: %{
                  association: :author,
                  id_key: "post_id"
                }
              }
            )
        end)

      resources_module = "Calcinator.Resources.Ecto.Repo.TestPosts"

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "get",
               "id" => to_string(id),
               "query_options" => "%{associations: [:author]}",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      source = "%Calcinator.Resources.TestPost{id: #{id}}"
      related = "%Calcinator.Resources.TestAuthor{id: #{related_id}}"

      # can(subject, :show, source)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => source
             } in calcinator_authorization_context_by_key_list

      # can(subject, :show, [related, source])
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "[#{related}, #{source}]"
             } in calcinator_authorization_context_by_key_list

      # authorized(calcinator, related)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => related
             } in calcinator_authorization_context_by_key_list

      assert %{
               "callback" => "show_relationship",
               "related_resource" => related,
               "source_association" => "author",
               "source_resource" => source,
               "subject" => @subject,
               "view_module" => "Calcinator.TestPostView"
             } in calcinator_view_context_by_key_list

      assert custom_metric_count == 7

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 3
                 }
               },
               "calcinator_view" => %{
                 "Calcinator" => %{
                   "view/3" => 1
                 }
               }
             }
    end

    test "update/3" do
      meta = checkout_meta()
      test_tag = Factory.insert(:test_tag)
      %TestPost{id: id} = Factory.insert(:test_post, tags: [test_tag])
      updated_body = "Updated Body"
      updated_test_tag = Factory.insert(:test_tag)

      params = %{
        "id" => to_string(id),
        "data" => %{
          "type" => "test-posts",
          "id" => to_string(id),
          "attributes" => %{
            "body" => updated_body
          },
          # Test `many_to_many` update does replacement
          "relationships" => %{
            "tags" => %{
              "data" => [
                %{
                  "type" => "test-tags",
                  "id" => to_string(updated_test_tag.id)
                }
              ]
            }
          }
        },
        "include" => "author,tags",
        "meta" => meta
      }

      %{
        context_by_key_list_by_event: %{
          "alembic" => alembic_context_by_key_list,
          "calcinator_authorization" => calcinator_authorization_context_by_key_list,
          "calcinator_resources" => calcinator_resources_context_by_key_list,
          "calcinator_view" => calcinator_view_context_by_key_list
        },
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } =
        custom_trace(%{group: "TestPost", key: "update"}, fn ->
          {:ok, _} =
            Calcinator.update(
              %Calcinator{
                associations_by_include: %{
                  "author" => :author,
                  "tags" => :tags
                },
                ecto_schema_module: TestPost,
                resources_module: TestPosts,
                view_module: TestPostView
              },
              params
            )
        end)

      assert %{"action" => ":update", "params" => inspect(params)} in alembic_context_by_key_list

      resources_module = "Calcinator.Resources.Ecto.Repo.TestPosts"
      before_update = "%Calcinator.Resources.TestPost{id: #{id}}"

      inspected_query_options =
        inspect(%{
          associations: [:author, :tags],
          filters: %{},
          meta: meta,
          page: nil,
          sorts: []
        })

      assert %{"callback" => "sandboxed?", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "beam" =>
                 meta
                 |> Beam.get()
                 |> inspect(),
               "callback" => "allow_sandbox_access",
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "get",
               "id" => "\"#{id}\"",
               "query_options" => inspected_query_options,
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      assert %{"callback" => "changeset", "resources_module" => resources_module} in calcinator_resources_context_by_key_list

      assert %{
               "callback" => "update",
               "changeset" => "%Ecto.Changeset{data: #{before_update}}",
               "query_options" => inspected_query_options,
               "resources_module" => resources_module
             } in calcinator_resources_context_by_key_list

      updated = "%Calcinator.Resources.TestPost{id: #{id}}"

      # can(subject, :show, before_update)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => before_update
             } in calcinator_authorization_context_by_key_list

      # can(subject, :update, changeset)
      assert %{
               "action" => "update",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "%Ecto.Changeset{data: #{before_update}}"
             } in calcinator_authorization_context_by_key_list

      # authorized(calcinator, updated)
      assert %{
               "action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => updated
             } in calcinator_authorization_context_by_key_list

      assert %{
               "callback" => "show",
               "resource" => updated,
               "subject" => @subject,
               "view_module" => "Calcinator.TestPostView"
             } in calcinator_view_context_by_key_list

      assert custom_metric_count == 10

      assert %{
               "alembic" => %{
                 "Calcinator" => %{
                   "document/2" => 1
                 }
               },
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               },
               "calcinator_resources" => %{
                 "Calcinator" => %{
                   "resources/3" => 5
                 }
               },
               "calcinator_view" => %{
                 "Calcinator" => %{
                   "view/3" => 1
                 }
               }
             } == custom_metric_count_by_function_by_module_by_key
    end
  end

  # Functions

  ## Private Functions

  defp assert_custom_metrics_filled(custom_metrics) do
    Enum.each(custom_metrics, fn custom_metric ->
      assert %PryIn.Interaction.CustomMetric{
               duration: duration,
               file: file,
               function: function,
               key: key,
               line: line,
               module: module,
               offset: offset,
               pid: pid
             } = custom_metric

      assert is_binary(function)
      assert is_integer(duration)
      assert is_binary(file)
      assert is_binary(key)
      assert is_integer(line)
      assert is_binary(module)
      assert is_integer(offset)
      assert is_binary(pid)
    end)
  end

  defp custom_trace(%{group: group, key: key}, fun) do
    interaction(fn ->
      CustomTrace.start(group: group, key: key)

      try do
        fun.()
      after
        CustomTrace.finish()
      end

      assert [%PryIn.Interaction{custom_group: ^group, custom_key: ^key, type: :custom_trace}] =
               InteractionStore.get_state().finished_interactions
    end)
  end

  defp interaction(fun) do
    fun.()

    assert [
             %PryIn.Interaction{
               context: context,
               custom_metrics: custom_metrics
             }
           ] = InteractionStore.get_state().finished_interactions

    assert is_list(context)

    assert is_list(custom_metrics)
    assert_custom_metrics_filled(custom_metrics)

    context_by_key_list_by_event =
      context
      |> Stream.map(fn {compound_key, value} ->
        [event, id, key] = String.split(compound_key, "/")
        {event, id, key, value}
      end)
      |> Enum.group_by(fn {event, _, _, _} -> event end)
      |> Enum.into(%{}, fn {event, entries} ->
        context_by_key_list =
          entries
          |> Enum.group_by(fn {_, id, _, _} -> id end)
          |> Enum.map(fn {id, entries} ->
            Enum.into(entries, %{}, fn {^event, ^id, key, value} -> {key, value} end)
          end)

        {event, context_by_key_list}
      end)

    custom_metric_count = length(custom_metrics)

    context_by_key_count =
      context_by_key_list_by_event
      |> Map.values()
      |> Stream.map(&length/1)
      |> Enum.sum()

    assert context_by_key_count == custom_metric_count

    custom_metric_count_by_function_by_module_by_key =
      custom_metrics
      |> Enum.reduce(%{}, fn %PryIn.Interaction.CustomMetric{function: function, key: key, module: module}, acc ->
        update_in(acc, [Access.key(key, %{}), Access.key(module, %{}), Access.key(function, 0)], &(&1 + 1))
      end)

    %{
      context_by_key_list_by_event: context_by_key_list_by_event,
      custom_metric_count: custom_metric_count,
      custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
    }
  end

  def jsonapify_conn(conn) do
    conn
    |> recycle()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  defp request(%{action: action, controller: controller}, fun) do
    interaction(fn ->
      fun.()

      assert [%PryIn.Interaction{action: ^action, controller: ^controller, type: :request}] =
               InteractionStore.get_state().finished_interactions
    end)
  end

  defp setup_conn(_) do
    {:ok, _} = Endpoint.start_link()

    conn =
      build_conn()
      |> jsonapify_conn()

    %{conn: conn}
  end

  defp setup_meta(_) do
    %{meta: checkout_meta()}
  end
end
