import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { AppModule } from "../../app.module";
import { PrismaService } from "../../prisma/prisma.service";
import {
  makeTestPrisma,
  resetDb,
  signupDetails,
} from "../../test-utils/test-prisma";

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

/** Needs pending SQL 007 (medicine_generics + its lower(name) unique index). */
d("Generic names over HTTP (real AppModule + Postgres)", () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(role: "USER" | "PHARMACIST") {
    seq += 1;
    const res = await http()
      .post("/api/auth/register")
      .send({
        phone: `+88017300${String(seq).padStart(5, "0")}`,
        name: `${role} ${seq}`,
        password: "pass1234",
        ...(await signupDetails(prisma)),
      })
      .expect(201);
    if (role !== "USER")
      await prisma.user.update({
        where: { id: res.body.user.id },
        data: { role },
      });
    return res.body.tokens.accessToken as string;
  }

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = "a".repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString("base64");
    delete process.env.LLM_API_BASE_URL;
    delete process.env.LLM_API_KEY;
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .compile();
    app = mod.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    app.setGlobalPrefix("api");
    await app.init();
  });
  afterAll(async () => {
    await app.close();
    await prisma.$disconnect();
  });
  beforeEach(async () => {
    await resetDb(prisma);
    await prisma.$executeRawUnsafe(
      "TRUNCATE prescriptions, medicines, medicine_generics, audit_logs RESTART IDENTITY CASCADE",
    );
  });

  it("typed generics are shared ignoring case, searchable, and removable from a medicine", async () => {
    const pharmacist = await account("PHARMACIST");
    const napa = await http()
      .post("/api/catalog/medicines")
      .set(auth(pharmacist))
      .send({ brandName: "Napa", genericName: "Paracetamol" })
      .expect(201);
    const ace = await http()
      .post("/api/catalog/medicines")
      .set(auth(pharmacist))
      .send({ brandName: "Ace", genericName: " paracetamol " })
      .expect(201);
    expect(napa.body.genericName).toBe("Paracetamol");
    expect(ace.body.generic.id).toBe(napa.body.generic.id);
    expect(await prisma.medicineGeneric.count()).toBe(1);

    const generics = await http()
      .get("/api/catalog/generics/search?q=PARA")
      .set(auth(pharmacist))
      .expect(200);
    expect(generics.body).toEqual([
      { id: napa.body.generic.id, name: "Paracetamol" },
    ]);

    // Medicine search still matches on the generic name.
    const medicines = await http()
      .get("/api/catalog/medicines/search?q=parac")
      .set(auth(pharmacist))
      .expect(200);
    expect(medicines.body.map((m: any) => m.brandName)).toEqual([
      "Ace",
      "Napa",
    ]);
    expect(medicines.body[0].genericName).toBe("Paracetamol");

    const cleared = await http()
      .patch(`/api/catalog/medicines/${napa.body.id}`)
      .set(auth(pharmacist))
      .send({ genericName: "" })
      .expect(200);
    expect(cleared.body.genericName).toBeNull();

    await http()
      .patch(`/api/catalog/medicines/${napa.body.id}`)
      .set(auth(pharmacist))
      .send({ genericId: 99999 })
      .expect(400);

    const picked = await http()
      .patch(`/api/catalog/medicines/${napa.body.id}`)
      .set(auth(pharmacist))
      .send({ genericId: ace.body.generic.id })
      .expect(200);
    expect(picked.body.genericName).toBe("Paracetamol");
  });

  it("the database itself refuses a second spelling that differs only in case", async () => {
    await prisma.medicineGeneric.create({ data: { name: "Omeprazole" } });
    await expect(
      prisma.medicineGeneric.create({ data: { name: "OMEPRAZOLE" } }),
    ).rejects.toMatchObject({
      code: "P2002",
    });
  });

  it("generic search is staff only", async () => {
    const patient = await account("USER");
    await http()
      .get("/api/catalog/generics/search?q=pa")
      .set(auth(patient))
      .expect(403);
  });
});
