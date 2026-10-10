import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { coursesApi } from "../../services/api";
import { Alert, Badge, PageHeader, formatPrice } from "../../components/ui";

function StudentCourses() {
    const [courses, setCourses] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        coursesApi.list().then((d) => setCourses(d.courses)).catch((e) => setError(e.message)).finally(() => setLoading(false));
    }, []);

    return (
        <div>
            <PageHeader title="Courses" />
            <Alert>{error}</Alert>
            {loading && <p>Loading...</p>}
            {!loading && courses.length === 0 && <p className="text-gray-500">No courses available yet.</p>}
            <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
                {courses.map((c) => (
                    <Link key={c.id} to={`/courses/${c.id}`} className="bg-white rounded-xl shadow hover:shadow-lg transition overflow-hidden block">
                        {c.image_url ? (
                            <img src={c.image_url} alt="" className="h-40 w-full object-cover" />
                        ) : (
                            <div className="h-40 bg-gradient-to-br from-blue-900 to-blue-500" />
                        )}
                        <div className="p-4">
                            <h3 className="font-bold text-blue-900">{c.course_name}</h3>
                            <p className="text-sm text-gray-600 line-clamp-2 mt-1">{c.description}</p>
                            <div className="flex items-center justify-between mt-3">
                                <span className="font-bold">{formatPrice(c.price)}</span>
                                {c.purchased ? <Badge>Active</Badge> : <span className="text-xs text-gray-500">{c.duration}</span>}
                            </div>
                        </div>
                    </Link>
                ))}
            </div>
        </div>
    );
}

export default StudentCourses;
