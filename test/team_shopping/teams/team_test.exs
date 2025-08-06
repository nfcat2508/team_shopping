defmodule TeamShopping.Teams.TeamTest do
  use TeamShopping.DataCase, async: true
  import ExUnitProperties
  import TeamShopping.Const

  alias TeamShopping.Teams

  describe "team creation" do
    setup :create_user

    test "returns a team with given valid input", %{user: user} do
      team = Teams.create!("Team Test", user.id)

      assert team.name == "Team Test"
      assert team.id
    end

    property "accepts all valid input", %{user: user} do
      check all(name <- StreamData.string(:alphanumeric, length: 1..45)) do
        Teams.create!(name, user.id)
      end
    end

    test "rejects names with invalid char", %{user: user} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} = Teams.create("test_with_#{c}", user.id)
          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end

    test "rejects nil for name", %{user: user} do
      assert {:error, _} = Teams.create(nil, user.id)
    end

    test "rejects empty name", %{user: user} do
      assert {:error, _} = Teams.create("", user.id)
      assert {:error, _} = Teams.create(" ", user.id)
    end

    test "rejects names longer than 45 chars", %{user: user} do
      name = String.duplicate("a", 46)
      assert {:error, _} = Teams.create(name, user.id)
    end

    test "trims name", %{user: user} do
      actual = Teams.create!(" trim both ", user.id)
      assert actual.name == "trim both"

      actual = Teams.create!(" trim begin", user.id)
      assert actual.name == "trim begin"

      actual = Teams.create!("trim end ", user.id)
      assert actual.name == "trim end"
    end
  end

  describe "team retrieval" do
    setup :create_user

    test "getting an existing team returns the team", %{user: user} do
      team = Teams.create!("test", user.id)

      actual = Teams.get!(team.id)

      assert actual.id == team.id
      assert actual.name == team.name
    end

    test "trying to get an unknown team returns an error", %{user: user} do
      Teams.create!("test", user.id)

      assert {:error, _} = Teams.get(Ecto.UUID.generate())
    end

    test "providing a non-uuid argument is invalid" do
      assert {:error, _} = Teams.get("jsdjnsdubsdlkashlakslasoaasisiasajdid")
    end
  end

  describe "team deletion" do
    setup :create_user

    test "deleting an existing team returns :ok", %{user: user} do
      team = Teams.create!("test", user.id)

      assert :ok == Teams.delete(team.id)
    end

    test "a deleted team cannot be retrieved anymore", %{user: user} do
      team = Teams.create!("test", user.id)

      Teams.delete(team.id)

      assert {:error, _} = Teams.get(team.id)
    end

    test "a team does not need to be empty to be deletable", %{user: user} do
      team = Teams.create!("test", user.id)
      Teams.add_member!(team.id, user.id, %{name: "Tester"})

      assert :ok == Teams.delete(team.id)
    end
  end
end
