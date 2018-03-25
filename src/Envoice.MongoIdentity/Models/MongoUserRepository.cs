using System.Threading;
using System.Threading.Tasks;
using Envoice.MongoIdentity.MongoDB;
using Envoice.MongoRepository;
using Microsoft.AspNetCore.Identity;
using MongoDB.Driver;

namespace Envoice.MongoIdentity.Models
{
  public class MongoUserRepository : MongoRepository<MongoIdentityUser>
  {
    #region [ Overridden Methods ]

    public override void Delete(MongoIdentityUser user, CancellationToken cancellationToken = default(CancellationToken))
    {
      user.Delete();
      this.Update(user, cancellationToken);
    }

    public async override Task DeleteAsync(MongoIdentityUser user, CancellationToken cancellationToken = default(CancellationToken))
    {
      user.Delete();
      await this.UpdateAsync(user, cancellationToken);
    }

    public override MongoIdentityUser GetById(string id, FindOptions<MongoIdentityUser> options = null, CancellationToken cancellationToken = default(CancellationToken))
    {
      var query = Builders<MongoIdentityUser>.Filter.And(
          Builders<MongoIdentityUser>.Filter.Eq(u => u.Id, id),
          Builders<MongoIdentityUser>.Filter.Eq(u => u.DeletedOn, null)
      );

      return this.Collection.FindSync<MongoIdentityUser>(query, options, cancellationToken).Single();
    }

    public async override Task<MongoIdentityUser> GetByIdAsync(string id, FindOptions options, CancellationToken cancellationToken = default(CancellationToken))
    {
      var query = Builders<MongoIdentityUser>.Filter.And(
          Builders<MongoIdentityUser>.Filter.Eq(u => u.Id, id),
          Builders<MongoIdentityUser>.Filter.Eq(u => u.DeletedOn, null)
      );

      return await this.Collection.Find<MongoIdentityUser>(query, options).SingleAsync(cancellationToken);
    }

    #endregion

    public async Task<MongoIdentityUser> FindByNameAsync(string normalizedUserName, CancellationToken cancellationToken)
    {
      var query = Builders<MongoIdentityUser>.Filter.And(
                Builders<MongoIdentityUser>.Filter.Eq(u => u.NormalizedUserName, normalizedUserName),
                Builders<MongoIdentityUser>.Filter.Eq(u => u.DeletedOn, null)
            );

      return await this.Collection.Find<MongoIdentityUser>(query).SingleAsync(cancellationToken);
    }
  }
}
