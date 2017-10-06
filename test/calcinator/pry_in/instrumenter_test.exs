defmodule Calcinator.PryIn.InstrumenterTest do
  use Calcinator.PryIn.Case

  import Calcinator.Resources.Ecto.Repo.Repo.Case

  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestPosts}
  alias Calcinator.Resources.{TestAuthor, TestPost}
  alias Calcinator.{TestAuthorView, TestPostView}
  alias PryIn.{CustomTrace, InteractionStore}

  @authorization_module "Calcinator.Authorization.SubjectLess"
  @subject "nil"

  describe "calcinator_authorization/3" do
    test "in Calcinator.create/2" do
      meta = checkout_meta()

      %TestAuthor{id: author_id} = Factory.insert(:test_author)
      body = "First Post!"

      %{
        context_by_key_list: context_by_key_list,
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } = custom_trace(
        %{group: "TestPost", key: "create"},
        fn ->
          assert {:ok, _} = Calcinator.create(
                   %Calcinator{
                     associations_by_include: %{
                       "author" => :author
                     },
                     ecto_schema_module: TestPost,
                     resources_module: TestPosts,
                     view_module: TestPostView
                   },
                   %{
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
                 )
        end
      )

      ecto_schema_module = "Calcinator.Resources.TestPost"

      # can(subject, :create, ecto_schema_module)
      assert %{"action" => "create",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => ecto_schema_module} in context_by_key_list
      # can(subject, :create, changeset)
      assert %{"action" => "create",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "%Ecto.Changeset{data: %#{ecto_schema_module}{}}"} in context_by_key_list
      # authorized(calcinator, created)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "%#{ecto_schema_module}{}"} in context_by_key_list

      assert custom_metric_count == 3

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               }
             }
    end

    test "in Calcinator.delete/2" do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      %{
        context_by_key_list: context_by_key_list,
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } = custom_trace(
        %{group: "TestAuthor", key: "delete"},
        fn ->
          :ok = Calcinator.delete(
            %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView},
            %{
              "id" => id,
              "meta" => meta
            }
          )
        end
      )

      assert %{"action" => "delete",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "%Calcinator.Resources.TestAuthor{}"} in context_by_key_list

      assert custom_metric_count == 1

      assert %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "can/3" => 1
                 }
               }
             } == custom_metric_count_by_function_by_module_by_key
    end

    test "in Calcinator.get_related_resource/3" do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      %{
        context_by_key_list: context_by_key_list,
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } = custom_trace(
        %{group: "TestPost", key: "get_related_resource"},
        fn ->
          {:ok, _} = Calcinator.get_related_resource(
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
        end
      )

      source = "%Calcinator.Resources.TestPost{}"
      related = "%Calcinator.Resources.TestAuthor{}"

      # can(subject, :show, source)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => source} in context_by_key_list
      # can(subject, :show, [related, source])
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "[#{related}, #{source}]"} in context_by_key_list
      # authorized(calcinator, related)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => related} in context_by_key_list

      assert custom_metric_count == 3

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               }
             }
    end

    test "in Calcinator.index/3" do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      %{
        context_by_key_list: context_by_key_list,
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } = custom_trace %{group: "TestAuthor", key: "index"}, fn ->
        assert {:ok, %{"data" => data}} = Calcinator.index(
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
      end

      assert %{"action" => "index",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "Calcinator.Resources.TestAuthor"} in context_by_key_list

      assert custom_metric_count == 1

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "can/3" => 1
                 }
               }
             }
    end

    test "in Calcinator.show/3" do
      meta = checkout_meta()
      test_author = Factory.insert(:test_author)

      %{
        context_by_key_list: context_by_key_list,
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } = custom_trace(
        %{group: "TestAuthor", key: "show"},
        fn ->
          {:ok, _} = Calcinator.show(
            %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView},
            %{
              "id" => test_author.id,
              "meta" => meta
            }
          )
        end
      )

      resource = "%Calcinator.Resources.TestAuthor{}"

      # can(subject, :show, resource)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => resource} in context_by_key_list
      # authorized(calcinator, resource)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => resource} in context_by_key_list

      assert custom_metric_count == 2

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 1
                 }
               }
             }
    end

    test "in Calcinator.show_relationship/3" do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      %{
        context_by_key_list: context_by_key_list,
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } = custom_trace(
        %{group: "TestPost", key: "show_relationship"},
        fn ->
          {:ok, _} = Calcinator.show_relationship(
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
        end
      )

      source = "%Calcinator.Resources.TestPost{}"
      related = "%Calcinator.Resources.TestAuthor{}"

      # can(subject, :show, source)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => source} in context_by_key_list
      # can(subject, :show, [related, source])
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "[#{related}, #{source}]"} in context_by_key_list
      # authorized(calcinator, related)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => related} in context_by_key_list

      assert custom_metric_count == 3

      assert custom_metric_count_by_function_by_module_by_key == %{
               "calcinator_authorization" => %{
                 "Calcinator" => %{
                   "authorized/2" => 1,
                   "can/3" => 2
                 }
               }
             }
    end

    test "in Calcinator.update/3" do
      meta = checkout_meta()
      test_tag = Factory.insert(:test_tag)
      %TestPost{id: id} = Factory.insert(:test_post, tags: [test_tag])
      updated_body = "Updated Body"
      updated_test_tag = Factory.insert(:test_tag)

      %{
        context_by_key_list: context_by_key_list,
        custom_metric_count: custom_metric_count,
        custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
      } = custom_trace(
        %{group: "TestPost", key: "update"},
        fn ->
          {:ok, _} = Calcinator.update(
            %Calcinator{
              associations_by_include: %{
                "author" => :author,
                "tags" => :tags
              },
              ecto_schema_module: TestPost,
              resources_module: TestPosts,
              view_module: TestPostView
            },
            %{
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
          )
        end
      )

      before_update = "%Calcinator.Resources.TestPost{}"
      updated = "%Calcinator.Resources.TestPost{}"

      # can(subject, :show, before_update)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => before_update} in context_by_key_list
      # can(subject, :update, changeset)
      assert %{"action" => "update",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => "%Ecto.Changeset{data: #{before_update}}"} in context_by_key_list
      # authorized(calcinator, updated)
      assert %{"action" => "show",
               "authorization_module" => @authorization_module,
               "subject" => @subject,
               "target" => updated} in context_by_key_list

      assert custom_metric_count == 3

      assert %{
              "calcinator_authorization"=> %{
               "Calcinator" => %{
      "authorized/2" => 1,
               "can/3"=> 2
        }
      }
             } == custom_metric_count_by_function_by_module_by_key
    end
  end

  # Functions

  ## Private Functions

  defp assert_custom_metrics_filled(custom_metrics) do
    Enum.each(
      custom_metrics,
      fn custom_metric ->
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
      end
    )
  end

  defp custom_trace(%{group: group, key: key}, fun) do
    CustomTrace.start(group: group, key: key)

    try do
      fun.()
    after
      CustomTrace.finish()
    end

    assert [
             %PryIn.Interaction{
               context: context,
               custom_group: ^group,
               custom_key: ^key,
               custom_metrics: custom_metrics,
               type: :custom_trace
             }
           ] = InteractionStore.get_state.finished_interactions

    assert is_list(context)

    assert is_list(custom_metrics)
    assert_custom_metrics_filled(custom_metrics)

    context_by_key_list = context
                          |> Stream.map(
                               fn {"calcinator/authorization/" <> suffix, value} ->
                                 [id, key] = String.split(suffix, "/")
                                 {id, key, value}
                               end
                             )
                          |> Enum.group_by(fn {id, _, _} -> id end)
                          |> Enum.sort_by(fn {id, _} -> id end)
                          |> Enum.map(
                               fn {id, entries} ->
                                 Enum.into(entries, %{}, fn {^id, key, value} -> {key, value} end)
                               end
                             )

    custom_metric_count = length(custom_metrics)

    assert length(context_by_key_list) == custom_metric_count

    custom_metric_count_by_function_by_module_by_key =
      custom_metrics
      |> Enum.reduce(
           %{},
           fn (%PryIn.Interaction.CustomMetric{function: function, key: key, module: module}, acc) ->
             update_in(acc, [Access.key(key, %{}), Access.key(module, %{}), Access.key(function, 0)], &(&1 + 1))
           end
         )

    %{
      context_by_key_list: context_by_key_list,
      custom_metric_count: custom_metric_count,
      custom_metric_count_by_function_by_module_by_key: custom_metric_count_by_function_by_module_by_key
    }
  end
end
