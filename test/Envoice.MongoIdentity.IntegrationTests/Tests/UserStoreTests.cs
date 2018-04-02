using Envoice.MongoIdentity.MongoDB;
using Microsoft.AspNetCore.Identity;
using MongoDB.Driver;
using Shouldly;
using System.Threading.Tasks;
using System.Threading;
using Xunit;

namespace Envoice.MongoIdentity.IntegrationTests.Tests
{
  public class UserStoreTests : TestsBase
  {
    private MongoUserStore<MongoIdentityUser> _userStore;

    public UserStoreTests()
    {
      this._userStore = new MongoUserStore<MongoIdentityUser>(Configuration.Database.ConnectionString, true);
    }

    [Fact]
    public async Task CanCreateAndDeleteUser()
    {
      var user = new MongoIdentityUser("test_account", "test@mongo.com");
      var createResult = await _userStore.CreateAsync(user, CancellationToken.None);

      createResult.ShouldNotBeNull();
      createResult.Succeeded.ShouldBeTrue();

      var deleteResult = await _userStore.DeleteAsync(user, CancellationToken.None);
      deleteResult.ShouldNotBeNull();
      deleteResult.Succeeded.ShouldBeTrue();
    }

    // [Fact]
    // public async Task CanUpdateUser() {

    //   var user = new MongoIdentityUser("test_account_2", "test@mongo.com");
    //   var createResult = await _userStore.CreateAsync(user, CancellationToken.None);
    // }

    [Fact]
    public async Task CanCreateMultipleUsers() {

      var user1 = new MongoIdentityUser("test_account_1", "test1@mongo.com");
      var createResult1 = await _userStore.CreateAsync(user1, CancellationToken.None);

      createResult1.ShouldNotBeNull();
      createResult1.Succeeded.ShouldBeTrue();

      var user2 = new MongoIdentityUser("test_account_2", "test2@mongo.com");
      var createResult2 = await _userStore.CreateAsync(user2, CancellationToken.None);

      createResult2.ShouldNotBeNull();
      createResult2.Succeeded.ShouldBeTrue();

      await _userStore.DeleteAsync(user1, CancellationToken.None);
      await _userStore.DeleteAsync(user2, CancellationToken.None);
    }
  }
}
