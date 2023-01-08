using UnityEngine;

namespace TrailsFX_Demos
{

	public class RotateObject : MonoBehaviour
	{

		public float speed = 100f;

		public Vector3 eulerAngles = Vector3.zero;

		void Start ()
		{
			// SetAngles ();
		}

		void Update ()
		{
			transform.Rotate (eulerAngles * (Time.deltaTime * speed));
			// if (Random.value > 0.995f) {
			// 	SetAngles ();
			// }
		}

		// void SetAngles ()
		// {
		// 	eulerAngles = new Vector3 (Random.value - 0.5f, Random.value - 0.5f, Random.value - 0.5f);
		// }
	}

}