defmodule TeamShopping.Teams.MemberTest do
  use TeamShopping.DataCase, async: true
  import TeamShopping.Const
  import TeamShopping.AssertHelper

  alias TeamShopping.Teams

  @valid_member_params %{"name" => "Kitty Deluxe"}

  setup :create_user

  setup context do
    [team: Teams.create!("test", context.user.id)]
  end

  describe "member addition" do
    test "adding a user to a team creates a member", %{user: user, team: team} do
      actual = Teams.add_member!(team.id, user.id, params_with(name: "Dr. Test"))

      assert actual.name == "Dr. Test"
      assert actual.team_id == team.id
      assert actual.user_id == user.id
    end

    test "rejects nil for name", %{user: user, team: team} do
      assert {:error, _} = Teams.add_member(team.id, user.id, params_with(name: nil))
    end

    test "rejects empty name", %{user: user, team: team} do
      assert {:error, _} = Teams.add_member(team.id, user.id, params_with(name: ""))
      assert {:error, _} = Teams.add_member(team.id, user.id, params_with(name: " "))
    end

    test "rejects names longer than 15 chars", %{user: user, team: team} do
      max_length = String.duplicate("a", 15)
      too_long = String.duplicate("a", 16)

      assert {:ok, _} = Teams.add_member(team.id, user.id, params_with(name: max_length))
      assert {:error, _} = Teams.add_member(team.id, user.id, params_with(name: too_long))
    end

    test "rejects names with invalid char", %{user: user, team: team} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} = Teams.add_member(team.id, user.id, params_with(name: "test_with_#{c}"))

          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end

    test "adding a user multiple times to the same group returns an error", %{
      user: user,
      team: team
    } do
      Teams.add_member!(team.id, user.id, @valid_member_params)

      assert {:error, _} = Teams.add_member(team.id, user.id)
    end

    test "adding a user to a team with a duplicate name returns an error", %{
      user: user,
      team: team
    } do
      user_2 = create_user("test2@user.no", "passspass")
      Teams.add_member!(team.id, user.id, params_with(name: "Thea"))

      assert {:error, error} = Teams.add_member(team.id, user_2.id, params_with(name: "Thea"))
      assert message(error) == "name already exists in this team"
    end

    test "multiple members can be added", %{user: user, team: team} do
      user_2 = create_user("test2@user.no", "passspass")
      Teams.add_member!(team.id, user.id, params_with(name: "Thea"))
      Teams.add_member!(team.id, user_2.id, params_with(name: "Hannah"))

      actual = members(team)

      assert length(actual) == 2
    end
  end

  describe "member removal" do
    test "removing a member returns :ok", %{user: user, team: team} do
      member = Teams.add_member!(team.id, user.id, @valid_member_params)

      assert :ok == Teams.remove_member!(member.id)
    end

    test "removing a member multiple times is ignored", %{user: user} do
      team = Teams.create!("test", user.id)
      member = Teams.add_member!(team.id, user.id, @valid_member_params)
      Teams.remove_member!(member.id)

      assert {:error, _} = Teams.remove_member(member.id)
    end
  end

  describe "members retrieval" do
    test "an empty list is returned for a team without members", %{team: team} do
      assert [] == Teams.team_members!(team.id)
    end

    test "returned list contains all team members", %{user: user, team: team} do
      member_1 = Teams.add_member!(team.id, user.id, params_with(name: "Cat"))

      [actual_1] = Teams.team_members!(team.id)
      assert actual_1.id == member_1.id

      user_2 = create_user("test2@user.no", "passspass")
      member_2 = Teams.add_member!(team.id, user_2.id, params_with(name: "Kitty"))

      actual = Teams.team_members!(team.id)
      assert Enum.find(actual, &(&1.id == member_1.id))
      assert Enum.find(actual, &(&1.id == member_2.id))
    end

    test "returned list contains members from requested team only", %{user: user, team: team} do
      team_2 = Teams.create!("test 2", user.id)

      member = Teams.add_member!(team.id, user.id, params_with(name: "Cat"))
      _other = Teams.add_member!(team_2.id, user.id, params_with(name: "Cat"))

      [actual] = Teams.team_members!(team.id)
      assert actual.id == member.id
    end

    test "returns error, if nil provided" do
      assert {:error, _} = Teams.team_members(nil)
    end
  end

  defp members(team) do
    Ash.load!(team, :members).members
  end

  defp params_with(opts) do
    Map.replace(
      @valid_member_params,
      "name",
      Keyword.get(opts, :name, @valid_member_params["name"])
    )
  end
end
