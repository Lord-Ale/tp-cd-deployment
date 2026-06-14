import { Test, TestingModule } from '@nestjs/testing';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';

const mockTasksService = {
  create: jest.fn(),
  findAll: jest.fn(),
  findOne: jest.fn(),
  update: jest.fn(),
  remove: jest.fn(),
};

describe('TasksController', () => {
  let controller: TasksController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [TasksController],
      providers: [{ provide: TasksService, useValue: mockTasksService }],
    }).compile();

    controller = module.get<TasksController>(TasksController);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('findAll() délègue à TasksService.findAll()', async () => {
    const tasks = [
      {
        id: 1,
        title: 'Test',
        content: null,
        done: false,
        createdAt: new Date(),
      },
    ];
    mockTasksService.findAll.mockResolvedValue(tasks);

    const result = await controller.findAll();

    expect(mockTasksService.findAll).toHaveBeenCalled();
    expect(result).toEqual(tasks);
  });

  it('create() délègue à TasksService.create()', async () => {
    const dto = { title: 'Nouvelle tâche' };
    const created = {
      id: 2,
      title: 'Nouvelle tâche',
      content: null,
      done: false,
      createdAt: new Date(),
    };
    mockTasksService.create.mockResolvedValue(created);

    const result = await controller.create(dto);

    expect(mockTasksService.create).toHaveBeenCalledWith(dto);
    expect(result).toEqual(created);
  });

  it("findOne() délègue à TasksService.findOne() avec l'ID parsé", async () => {
    const task = {
      id: 1,
      title: 'Test',
      content: null,
      done: false,
      createdAt: new Date(),
    };
    mockTasksService.findOne.mockResolvedValue(task);

    const result = await controller.findOne(1);

    expect(mockTasksService.findOne).toHaveBeenCalledWith(1);
    expect(result).toEqual(task);
  });

  it('update() délègue à TasksService.update()', async () => {
    const task = {
      id: 1,
      title: 'Modifiée',
      content: null,
      done: false,
      createdAt: new Date(),
    };
    mockTasksService.update.mockResolvedValue(task);

    const result = await controller.update(1, { title: 'Modifiée' });

    expect(mockTasksService.update).toHaveBeenCalledWith(1, {
      title: 'Modifiée',
    });
    expect(result).toEqual(task);
  });

  it('remove() délègue à TasksService.remove()', async () => {
    const task = {
      id: 1,
      title: 'Test',
      content: null,
      done: false,
      createdAt: new Date(),
    };
    mockTasksService.remove.mockResolvedValue(task);

    const result = await controller.remove(1);

    expect(mockTasksService.remove).toHaveBeenCalledWith(1);
    expect(result).toEqual(task);
  });
});
