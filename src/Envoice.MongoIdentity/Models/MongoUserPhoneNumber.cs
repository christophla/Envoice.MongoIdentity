namespace Envoice.MongoIdentity.Models
{
    public class MongoUserPhoneNumber : MongoUserContactRecord
    {
        public MongoUserPhoneNumber(string phoneNumber) : base(phoneNumber)
        {
        }
    }
}
