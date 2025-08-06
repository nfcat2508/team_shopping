## Getting started

You can run the project locally with the following steps:

1. Copy this repo via `git clone` or by downloading it
2. Have postgres database running locally accessible with username "postgres" and password: "postgres" 
3. Run the `mix setup` Mix task from within the projects directory
4. Run the `mix phx.server` Mix task from within the projects directory
5. Open http://localhost:4000 and login with one of the following users:

| Email                    | Password     |
|:-------------------------|:-------------|
| user1@test.de&nbsp;&nbsp;| password4242 |
| user2@test.de&nbsp;&nbsp;| password4242 |
| user3@test.de&nbsp;&nbsp;| password4242 |

```bash
git clone https://github.com/nfcat2508/team_shopping.git
cd team_shopping
mix setup
mix phx.server
```

## About the app
* users can create shopping lists and assign them to a team.
* each team member can add/remove items to the shopping list and update the item status
* all team members can see the updates done by any team member without browser refresh
* each user can create a personal list of articles which can be used to add with on click to the shopping list
* the following users and teams are created by the steps from `Getting started`:

| Email                    | Team        | Name               |
|:-------------------------|:------------|:-------------------|
| user1@test.de&nbsp;&nbsp;| Shoppers_12&nbsp;&nbsp; | Thea   |
| user2@test.de&nbsp;&nbsp;| Shoppers_12&nbsp;&nbsp; | Hanna  |
| user1@test.de&nbsp;&nbsp;| Shoppers_13&nbsp;&nbsp; | Miss T |
| user3@test.de&nbsp;&nbsp;| Shoppers_13&nbsp;&nbsp; | Olga   |


## About the used technologies
* Ash Framework
* Phoenix LiveView
* Phoenix.PubSub
* installable as a PWA
